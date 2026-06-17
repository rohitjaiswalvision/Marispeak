import UIKit
import Flutter
import Firebase
import FirebaseMessaging
import AVFoundation
import PushKit
import CallKit
import PushToTalk
import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - NativePTTPlayer
// Pure-Swift background WebSocket + audio player.
// Runs entirely without Flutter — works when phone is locked/app suspended.
// ─────────────────────────────────────────────────────────────────────────────
class NativePTTPlayer: NSObject, URLSessionWebSocketDelegate {

    static let shared = NativePTTPlayer()
    private override init() { super.init() }

    private var webSocketTask: URLSessionWebSocketTask?
    private var currentDisconnectToken: UUID?
    private var endTransactionTimer: Timer?
    
    // ✅ Must wait for PushToTalk to fully activate before playing!
    var isAudioSessionActive = false 

    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private var audioPlayer: AVAudioPlayer?
    private var isReceiving = false
    private var disconnectTimer: Timer?
    
    // ✅ Queue for audio chunks so they don't overlap
    private var audioQueue: [Data] = []
    private var isPlaying = false

    // ✅ Called when a VoIP push arrives — connect and play in background
    func startBackgroundReceive(groupId: String) {
        // Read current userId that Flutter saved in SharedPreferences (UserDefaults key: flutter.ptt_user_id)
        let userId = UserDefaults.standard.string(forKey: "flutter.ptt_user_id") ?? ""
        guard !userId.isEmpty else {
            print("⚠️ NativePTTPlayer: No userId in UserDefaults — cannot connect")
            return
        }
        
        // ✅ Prevent duplicate pushes from killing the existing connection and losing audio!
        if NativePTTPlayer.shared.isReceiving && NativePTTPlayer.shared.webSocketTask != nil {
            print("✅ NativePTTPlayer: Already receiving, ignoring duplicate VoIP push trigger")
            return
        }
        
        // Disconnect any hanging connection
        disconnect()
        isReceiving = true

        print("🔊 NativePTTPlayer: Connecting as \(userId) to receive group \(groupId)")

        guard let url = URL(string: "ws://192.168.3.192:3010") else { return } // 🔧 LOCAL TESTING
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()

        // Register
        sendMessage(["type": "register", "userId": userId])
        // Join the target group (the groupId from the push payload = sender's channel)
        sendMessage(["type": "switch", "newGroupId": groupId])

        // Start receiving audio chunks
        receiveNextMessage()

        // Auto-disconnect after 45s (saves battery, PTT messages are short)
        DispatchQueue.main.asyncAfter(deadline: .now() + 45) { [weak self] in
            self?.disconnect()
        }
    }

    private func sendMessage(_ dict: [String: String]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(str)) { _ in }
    }

    private func receiveNextMessage() {
        guard isReceiving else { return }
        webSocketTask?.receive { [weak self] result in
            guard let self = self, self.isReceiving else { return }
            switch result {
            case .success(let message):
                DispatchQueue.main.async {
                    self.endTransactionTimer?.invalidate() // ✅ Cancel the shutdown, more chunks are arriving!
                }
                if case .string(let text) = message {
                    self.handleMessage(text)
                }
                self.receiveNextMessage() // ✅ Keep listening for more chunks
            case .failure(let error):
                print("⚠️ NativePTTPlayer receive error: \(error.localizedDescription)")
                self.isReceiving = false
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String,
              type == "audio",
              let chunk = json["chunk"] as? String,
              let audioData = Data(base64Encoded: chunk) else { return }

        print("🔊 NativePTTPlayer: Received \(audioData.count) bytes of audio")
        
        DispatchQueue.main.async {
            self.audioQueue.append(audioData)
            self.processQueue()
        }
    }

    // Called from AppDelegate when the system is absolutely ready
    func sessionDidActivate() {
        isAudioSessionActive = true
        processQueue() // Start playing any queued chunks!
    }

    private func processQueue() {
        guard isAudioSessionActive, !isPlaying, !audioQueue.isEmpty else { return }
        isPlaying = true
        
        let data = audioQueue.removeFirst()
        playAudio(data: data)
    }

    private func playAudio(data: Data) {
        do {
            let tempDir = FileManager.default.temporaryDirectory
            let tempFileUrl = tempDir.appendingPathComponent(UUID().uuidString + ".m4a")
            try data.write(to: tempFileUrl)

            audioPlayer = try AVAudioPlayer(contentsOf: tempFileUrl)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            print("✅ NativePTTPlayer: Audio chunk playing on speaker")
        } catch {
            print("❌ NativePTTPlayer: Audio playback error: \(error)")
            self.isPlaying = false
            self.processQueue() // skip to next
        }
    }

    func disconnect() {
        isReceiving = false
        isAudioSessionActive = false // Reset
        isPlaying = false
        audioQueue.removeAll()
        audioPlayer?.stop()
        audioPlayer = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        print("🔌 NativePTTPlayer: Disconnected")
    }

    // URLSessionWebSocketDelegate
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
        print("✅ NativePTTPlayer: WebSocket connected")
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("🔌 NativePTTPlayer: WebSocket closed")
        isReceiving = false
    }
}

extension NativePTTPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        if audioQueue.isEmpty {
            // ✅ Wait 3.5 seconds before ending the transaction. 
            // Because Android streams in 1.5s chunks, we must not close the connection 
            // between chunks or else the voice will cut off mid-sentence!
            DispatchQueue.main.async {
                self.endTransactionTimer?.invalidate()
                self.endTransactionTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { _ in
                    NotificationCenter.default.post(name: NSNotification.Name("PTTAudioFinished"), object: nil)
                }
            }
        } else {
            processQueue() // Play next chunk if any
        }
    }
}

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
        // ✅ Listen for when the background audio finishes playing
        NotificationCenter.default.addObserver(forName: NSNotification.Name("PTTAudioFinished"), object: nil, queue: .main) { _ in
            if let manager = self.channelManager as? PTChannelManager, let activeUUID = manager.activeChannelUUID {
                print("🛑 Ending PTT Active Remote Participant")
                manager.setActiveRemoteParticipant(nil, channelUUID: activeUUID, completionHandler: nil)
            }
        }

        PTChannelManager.channelManager(delegate: self, restorationDelegate: self) { manager, error in
            if let error = error {
                print("❌ Failed to initialize PTChannelManager: \(error)")
            } else if let manager = manager {
                self.channelManager = manager
                // Request to join a default Walkie-Talkie channel so we can receive pushes
                let channelUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
                let descriptor = PTChannelDescriptor(name: "Walkie-Talkie", image: nil)
                
                if let activeUUID = manager.activeChannelUUID {
                    if activeUUID == channelUUID {
                        print("✅ Already joined PTT Channel")
                    } else {
                        print("♻️ Leaving previous PTT channel to prevent limit error")
                        manager.leaveChannel(channelUUID: activeUUID)
                        manager.requestJoinChannel(channelUUID: channelUUID, descriptor: descriptor)
                    }
                } else {
                    manager.requestJoinChannel(channelUUID: channelUUID, descriptor: descriptor)
                }
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
        } else if call.method == "getPendingVoIPPayload" {
          // ✅ Flutter reads this on resume to catch push received while locked
          let payload = UserDefaults.standard.dictionary(forKey: "pending_voip_payload")
          result(payload)
        } else if call.method == "clearPendingVoIPPayload" {
          // ✅ Clear after Flutter has processed it
          UserDefaults.standard.removeObject(forKey: "pending_voip_payload")
          result(nil)
        } else if call.method == "isAppInBackground" {
          // ✅ Tell Flutter if the app is truly in the background or not
          let state = UIApplication.shared.applicationState
          result(state == .background || state == .inactive)
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
        
        // 🚨 QUICK HACK: Instantly "hang up" the CallKit call after 10 seconds 
        // This gives us enough background execution time to download and play the chunk!
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
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

    // ✅ Start native background WebSocket + audio player (works with phone locked)
    // This plays audio WITHOUT involving Flutter at all
    let payloadData = payload.dictionaryPayload
    let groupId = payloadData["groupId"] as? String ?? ""
    if !groupId.isEmpty {
        NativePTTPlayer.shared.startBackgroundReceive(groupId: groupId)
    }

    // ✅ Also notify Flutter that VoIP push was received (for when it resumes)
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
    // ✅ ALWAYS persist payload to UserDefaults FIRST
    // This ensures Flutter can read it even if the engine isn't ready yet
    var stringPayload: [String: String] = [:]
    for (key, value) in payload {
      if let k = key as? String {
        stringPayload[k] = "\(value)"
      }
    }
    UserDefaults.standard.set(stringPayload, forKey: "pending_voip_payload")
    UserDefaults.standard.synchronize()
    print("📦 VoIP payload persisted to UserDefaults: \(stringPayload)")

    // ✅ Try to deliver to Flutter immediately (works when app is foreground/active)
    _deliverVoIPPayloadToFlutter(stringPayload, retries: 5)
  }

  private func _deliverVoIPPayloadToFlutter(_ payload: [String: String], retries: Int) {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      // Flutter engine not ready yet — retry after a short delay
      if retries > 0 {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
          self._deliverVoIPPayloadToFlutter(payload, retries: retries - 1)
        }
      } else {
        print("⚠️ Flutter not ready after retries — payload stored in UserDefaults for resume")
      }
      return
    }
    let channel = FlutterMethodChannel(name: "ptt/voip", binaryMessenger: controller.binaryMessenger)
    DispatchQueue.main.async {
      channel.invokeMethod("onVoIPPush", arguments: payload)
      print("✅ VoIP payload delivered to Flutter")
      // Clear persisted payload once successfully delivered
      UserDefaults.standard.removeObject(forKey: "pending_voip_payload")
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

        // ✅ Start native background WebSocket + audio player (works with phone locked)
        // This plays audio WITHOUT involving Flutter at all
        let groupId = pushPayload["groupId"] as? String ?? ""
        if !groupId.isEmpty {
            NativePTTPlayer.shared.startBackgroundReceive(groupId: groupId)
        }

        // ✅ Also notify Flutter (with UserDefaults fallback for when it's ready)
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
        NativePTTPlayer.shared.sessionDidActivate()
    }
    
    func channelManager(_ channelManager: PTChannelManager, didDeactivate audioSession: AVAudioSession) {
        print("🎙️ PTT Audio Session Deactivated")
        NativePTTPlayer.shared.disconnect()
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
