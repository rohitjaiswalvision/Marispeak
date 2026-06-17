import UIKit
import Flutter
import Firebase
import FirebaseMessaging
import AVFoundation
import PushKit
import CallKit
import PushToTalk

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate {

  // CallKit provider for required iOS 13+ VoIP push compliance
  var callProvider: CXProvider?
  var callController = CXCallController()
  var activeCallUUID: UUID?
  var channelManager: Any? // PTChannelManager on iOS 16+

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // ✅ Configure Firebase
    FirebaseApp.configure()

    // ✅ Set up push notification delegate
    UNUserNotificationCenter.current().delegate = self

    // ✅ Register for remote notifications
    application.registerForRemoteNotifications()

    // ✅ Register Flutter plugins
    GeneratedPluginRegistrant.register(with: self)

    // ✅ Set up CallKit provider (required when using PushKit on iOS 13+)
    let config = CXProviderConfiguration()
    config.supportsVideo = false
    config.maximumCallsPerCallGroup = 1
    config.supportedHandleTypes = [.generic]
    callProvider = CXProvider(configuration: config)
    callProvider?.setDelegate(self, queue: nil)

    // ✅ Initialize Push To Talk Framework (iOS 16+)
    if #available(iOS 16.0, *) {
        PTChannelManager.channelManager(delegate: self, restorationDelegate: self) { manager, error in
            if let error = error {
                print("❌ Failed to initialize PTChannelManager: \(error)")
            } else if let manager = manager {
                self.channelManager = manager
                // Request to join a default Walkie-Talkie channel so we can receive pushes
                let channelUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
                let descriptor = PTChannelDescriptor(name: "Walkie-Talkie", image: nil)
                manager.requestJoinChannel(channelUUID: channelUUID, descriptor: descriptor)
            }
        }
    } else {
        // ✅ Register for VoIP push notifications (PushKit - for iOS < 16 ONLY)
        let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [.voIP]
    }

    // ✅ Set up custom audio method channel
    if let controller = window?.rootViewController as? FlutterViewController {

      let audioChannel = FlutterMethodChannel(name: "custom.audio", binaryMessenger: controller.binaryMessenger)
      audioChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in

        if call.method == "forceSpeaker" {
          self.forceSpeakerAfterDisable()
          result(nil)
        } else if call.method == "forceMic" {
          self.configureAudioSession()
          result(nil)
        } else if call.method == "forceVideoChat" {
          self.configureVideoChatAudioSession()
          result(nil)
        }
      }

      // ✅ Set up VoIP method channel (Flutter → Native registration)
      let voipChannel = FlutterMethodChannel(name: "ptt/voip", binaryMessenger: controller.binaryMessenger)
      voipChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "getVoIPToken" {
          result(UserDefaults.standard.string(forKey: "voip_token"))
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // ─────────────────────────────────────────────────────
  // MARK: - PushKit VoIP Delegate
  // ─────────────────────────────────────────────────────

  // ✅ Called when a new VoIP push token is available
  func pushRegistry(_ registry: PKPushRegistry,
                    didUpdate pushCredentials: PKPushCredentials,
                    for type: PKPushType) {
    let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    print("📲 VoIP Push Token: \(token)")
    // Store token locally so Flutter can retrieve it
    UserDefaults.standard.set(token, forKey: "voip_token")
    // Send token to Flutter side immediately if the view is ready
    sendVoIPTokenToFlutter(token)
  }

  // ✅ Called when a VoIP push arrives (wakes the app even when locked/killed)
  func pushRegistry(_ registry: PKPushRegistry,
                    didReceiveIncomingPushWith payload: PKPushPayload,
                    for type: PKPushType,
                    completion: @escaping () -> Void) {

    print("📨 VoIP Push Received: \(payload.dictionaryPayload)")

    // ✅ MANDATORY on iOS 13+: Report a call to CallKit immediately
    // If we skip this, Apple will kill the app
    let uuid = UUID()
    activeCallUUID = uuid
    let update = CXCallUpdate()
    update.remoteHandle = CXHandle(type: .generic, value: "PTT Message")
    update.hasVideo = false
    update.localizedCallerName = payload.dictionaryPayload["senderName"] as? String ?? "PTT Message"

    callProvider?.reportNewIncomingCall(with: uuid, update: update) { error in
      if let error = error {
        print("❌ CallKit report error: \(error)")
      } else {
        print("✅ CallKit call reported")
        
        // 🚨 QUICK HACK: Instantly "hang up" the CallKit call after 0.5 seconds 
        // so it doesn't keep ringing like a phone call.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let endCallAction = CXEndCallAction(call: uuid)
            let transaction = CXTransaction(action: endCallAction)
            self.callController.request(transaction, completion: { error in
                if let error = error {
                    print("⚠️ Failed to auto-end call: \(error)")
                } else {
                    print("🤫 Auto-ended CallKit to hide ringing UI")
                }
            })
        }
      }
      completion()
    }

    // ✅ Activate audio session to play received PTT audio
    activateAudioSessionForPTT()

    // ✅ Notify Flutter that VoIP push was received
    let payloadData = payload.dictionaryPayload
    sendVoIPPushToFlutter(payloadData)
  }

  // ─────────────────────────────────────────────────────
  // MARK: - Audio Session Helpers
  // ─────────────────────────────────────────────────────

  private func activateAudioSessionForPTT() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playAndRecord,
                              options: [.defaultToSpeaker, .mixWithOthers, .allowBluetooth])
      try session.setMode(.voiceChat)
      try session.setActive(true)
      print("✅ AVAudioSession activated for PTT delivery")
    } catch {
      print("⚠️ Failed to activate audio session for PTT: \(error)")
    }
  }

  private func configureAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playAndRecord,
                              options: [.defaultToSpeaker, .mixWithOthers])
      try session.setMode(.videoChat)
      try session.setActive(true)
      print("✅ AVAudioSession configured (no telephony mode)")
    } catch {
      print("⚠️ Failed to configure AVAudioSession: \(error)")
    }
  }

  private func configureVideoChatAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playAndRecord,
                              options: [.defaultToSpeaker, .allowBluetooth])
      try session.setMode(.videoChat)
      try session.setActive(true)
      print("✅ AVAudioSession switched to videoChat")
    } catch {
      print("❌ Failed to set videoChat session: \(error)")
    }
  }

  private func forceSpeakerAfterDisable() {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers])
      try session.setActive(true)
      try session.overrideOutputAudioPort(.speaker)
      print("🔊 Speaker forced in playAndRecord mode")
    } catch {
      print("❌ Failed to force speaker: \(error)")
    }
  }

  // ─────────────────────────────────────────────────────
  // MARK: - Flutter Channel Helpers
  // ─────────────────────────────────────────────────────

  private func sendVoIPTokenToFlutter(_ token: String) {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    let channel = FlutterMethodChannel(name: "ptt/voip", binaryMessenger: controller.binaryMessenger)
    DispatchQueue.main.async {
        channel.invokeMethod("onVoIPToken", arguments: token)
    }
  }

  private func sendVoIPPushToFlutter(_ payload: [AnyHashable: Any]) {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    let channel = FlutterMethodChannel(name: "ptt/voip", binaryMessenger: controller.binaryMessenger)
    // Convert payload to String:Any for Flutter
    let stringPayload = payload.reduce(into: [String: String]()) { result, pair in
      if let key = pair.key as? String {
        result[key] = "\(pair.value)"
      }
    }
    DispatchQueue.main.async {
        channel.invokeMethod("onVoIPPush", arguments: stringPayload)
    }
  }

  // ─────────────────────────────────────────────────────
  // MARK: - APNs Token Registration
  // ─────────────────────────────────────────────────────

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    #if DEBUG
    Auth.auth().setAPNSToken(deviceToken, type: .sandbox)
    #else
    Auth.auth().setAPNSToken(deviceToken, type: .prod)
    #endif

    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
  }
}

// ─────────────────────────────────────────────────────
// MARK: - CallKit Provider Delegate (Required for PushKit)
// ─────────────────────────────────────────────────────
extension AppDelegate: CXProviderDelegate {
  func providerDidReset(_ provider: CXProvider) {}

  func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "ptt/voip", binaryMessenger: controller.binaryMessenger)
      channel.invokeMethod("onCallAnswered", arguments: nil)
    }
    action.fulfill()
  }

  func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "ptt/voip", binaryMessenger: controller.binaryMessenger)
      channel.invokeMethod("onCallEnded", arguments: nil)
    }
    action.fulfill()
  }
}

// ─────────────────────────────────────────────────────
// MARK: - Push To Talk Framework Delegates (iOS 16+)
// ─────────────────────────────────────────────────────
@available(iOS 16.0, *)
extension AppDelegate: PTChannelManagerDelegate, PTChannelRestorationDelegate {
    
    func channelManager(_ channelManager: PTChannelManager, receivedEphemeralPushToken pushToken: Data) {
        let token = pushToken.map { String(format: "%02x", $0) }.joined()
        print("📲 PTT Framework VoIP Token: \(token)")
        UserDefaults.standard.set(token, forKey: "voip_token")
        sendVoIPTokenToFlutter(token)
    }
    
    func incomingPushResult(channelManager: PTChannelManager, channelUUID: UUID, pushPayload: [String : Any]) -> PTPushResult {
        print("📨 PTT Push Received: \(pushPayload)")
        
        // Notify Flutter
        sendVoIPPushToFlutter(pushPayload)
        
        let sender = pushPayload["senderName"] as? String ?? "Walkie-Talkie"
        let participant = PTParticipant(name: sender, image: nil)
        return .activeRemoteParticipant(participant)
    }
    
    func channelDescriptor(restoredChannelUUID channelUUID: UUID) -> PTChannelDescriptor {
        return PTChannelDescriptor(name: "Walkie-Talkie", image: nil)
    }
    
        
    func channelManager(_ channelManager: PTChannelManager, didActivate audioSession: AVAudioSession) {
        print("🎙️ PTT Audio Session Activated")
    }
    
    func channelManager(_ channelManager: PTChannelManager, didDeactivate audioSession: AVAudioSession) {
        print("🎙️ PTT Audio Session Deactivated")
    }

    func channelManager(_ channelManager: PTChannelManager, didJoinChannel channelUUID: UUID, reason: PTChannelJoinReason) {
        print("🎙️ Joined PTT Channel")
    }
    
    func channelManager(_ channelManager: PTChannelManager, didLeaveChannel channelUUID: UUID, reason: PTChannelLeaveReason) {
        print("🎙️ Left PTT Channel")
    }
    
    func channelManager(_ channelManager: PTChannelManager, channelUUID: UUID, didBeginTransmittingFrom source: PTChannelTransmitRequestSource) {
        print("🎙️ Began Transmitting")
    }
    
    func channelManager(_ channelManager: PTChannelManager, channelUUID: UUID, didEndTransmittingFrom source: PTChannelTransmitRequestSource) {
        print("🎙️ Ended Transmitting")
    }
    
    func channelManager(_ channelManager: PTChannelManager, failedToJoinChannel channelUUID: UUID, error: Error) {
        print("❌ Failed to join PTT Channel: \(error)")
    }
}
