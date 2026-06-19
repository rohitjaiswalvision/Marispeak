import UIKit
import Flutter
import Firebase
import FirebaseMessaging
import AVFoundation
import PushKit
import CallKit
import PushToTalk
import Foundation
import CryptoKit

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
    
    // ✅ For Native Sending (Lock Screen PTT)
    var currentGroupId: String?
    private var audioRecorder: AVAudioRecorder?
    private var chunkTimer: Timer?
    private var currentRecordFileUrl: URL?
    private var isTransmitting = false

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
        
        // ⚠️ Prevent duplicate pushes from killing the existing connection and losing audio!
        if NativePTTPlayer.shared.isReceiving && NativePTTPlayer.shared.webSocketTask != nil {
            print("✅ NativePTTPlayer: Already receiving, ignoring duplicate VoIP push trigger")
            return
        }
        
        // Disconnect any hanging WebSocket WITHOUT resetting the audio session state.
        // iOS may NOT re-fire sessionDidActivate if the PTT session is already active!
        softDisconnect()
        isReceiving = true

        print("🔊 NativePTTPlayer: Connecting as \(userId) to receive group \(groupId)")

        // ✅ FORCE development server for now (UserDefaults might not be set yet)
        let storedUrl = UserDefaults.standard.string(forKey: "flutter.ptt_server_url")
        let serverUrl = storedUrl ?? "wss://ptt.visionvivante.in" // Default to prod
        print("🔗 Stored URL: \(storedUrl ?? "nil"), Using: \(serverUrl)")
        
        guard let url = URL(string: serverUrl) else { 
            print("❌ Invalid PTT server URL: \(serverUrl)")
            return 
        }
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

        // ✅ FIX: Ignore our own audio chunks to prevent local echo
        let senderId = json["sender"] as? String ?? ""
        let myUserId = UserDefaults.standard.string(forKey: "flutter.ptt_user_id") ?? ""
        if !senderId.isEmpty && senderId == myUserId {
            print("🔇 NativePTTPlayer: Ignoring our own audio chunk")
            return
        }

        print("🔊 NativePTTPlayer: Received \(audioData.count) bytes of audio")
        
        DispatchQueue.main.async {
            self.audioQueue.append(audioData)
            print("📦 Queue size: \(self.audioQueue.count), isPlaying: \(self.isPlaying), sessionActive: \(self.isAudioSessionActive)")
            // ⚡ If sessionDidActivate already fired (consecutive push), play immediately.
            // If session isn't active yet, processQueue() will be triggered by sessionDidActivate.
            self.forceStartIfSessionActive()
        }
    }

    // Called from AppDelegate when the system is absolutely ready
    func sessionDidActivate(audioSession: AVAudioSession? = nil) {
        isAudioSessionActive = true
        
        // 🚨 CRITICAL APPLE RULE: If the system provided the audioSession (via PushToTalk),
        // it is ALREADY active and fully configured for Walkie-Talkie (including Speaker routing).
        // Modifying the category or overriding the port will crash Apple's internal routing!
        if audioSession == nil {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth])
                try session.setActive(true)
                try session.overrideOutputAudioPort(.speaker)
                print("🔊 NativePTTPlayer: Local audio session active — full-volume speaker output")
            } catch {
                print("❌ NativePTTPlayer: Failed to configure local speaker - \(error)")
            }
        } else {
            print("🔊 NativePTTPlayer: PushToTalk audio session active — relying on system routing")
        }

        processQueue() // Start playing any queued chunks!
        
        // If the user pressed Talk and we were waiting for the session to activate:
        if isTransmitting && audioRecorder == nil {
            print("🎙️ Starting to record audio chunks (Session is now active)...")
            startRecordingChunk()

            chunkTimer?.invalidate()
            chunkTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
                self?.flushAndContinueRecording()
            }
            print("⏱️ Chunk timer started (1.5s interval)")
        }
    }

    // Called when a NEW push arrives and session might ALREADY be active.
    // Force-start the queue immediately without waiting for sessionDidActivate.
    func forceStartIfSessionActive() {
        if isAudioSessionActive {
            print("⚡ NativePTTPlayer: Session already active — force-starting queue")
            processQueue()
        }
    }

    private func processQueue() {
        print("🎬 processQueue called: sessionActive=\(isAudioSessionActive), isPlaying=\(isPlaying), queueSize=\(audioQueue.count)")
        guard isAudioSessionActive, !isPlaying, !audioQueue.isEmpty else { 
            if !isAudioSessionActive {
                print("⚠️ Cannot process queue: audio session not active yet")
            }
            return 
        }
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
            audioPlayer?.volume = 1.0  // ✅ FIX: Explicitly set max volume (default is not guaranteed)
            audioPlayer?.prepareToPlay()  // ✅ Pre-buffer audio to reduce playback latency
            audioPlayer?.play()
            print("✅ NativePTTPlayer: Audio chunk playing at full volume on speaker")
        } catch {
            print("❌ NativePTTPlayer: Audio playback error: \(error)")
            self.isPlaying = false
            self.processQueue() // skip to next
        }
    }

    // 🔌 Soft disconnect: closes WebSocket but PRESERVES isAudioSessionActive.
    // Use this between consecutive pushes when the PTT session may still be active.
    // iOS will NOT re-fire sessionDidActivate if already active!
    func softDisconnect() {
        isReceiving = false
        isPlaying = false
        audioQueue.removeAll()
        audioPlayer?.stop()
        audioPlayer = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        print("🔌 NativePTTPlayer: Soft-disconnected (audio session state preserved)")
    }

    // 🔴 Full disconnect: resets ALL state including audio session flag.
    // Only call this when the PTT session has officially ended (didDeactivate fires).
    func disconnect() {
        isReceiving = false
        isTransmitting = false
        isAudioSessionActive = false // ✅ ONLY reset here (when PTT session truly ends)
        isPlaying = false
        audioQueue.removeAll()
        audioPlayer?.stop()
        audioPlayer = nil
        chunkTimer?.invalidate()
        chunkTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        print("🔌 NativePTTPlayer: Disconnected")
    }

    // ────────────────────────────────────────────────────────────
    // MARK: - Native Transmitting (Lock Screen PTT)
    // ────────────────────────────────────────────────────────────
    func startTransmitting(groupId: String) {
        print("🎤 startTransmitting called for group: \(groupId)")
        
        let userId = UserDefaults.standard.string(forKey: "flutter.ptt_user_id") ?? ""
        print("👤 User ID: \(userId)")
        
        guard !userId.isEmpty else {
            print("❌ Cannot transmit: No userId in UserDefaults")
            return
        }

        isTransmitting = true
        self.currentGroupId = groupId
        print("✅ isTransmitting = true, currentGroupId = \(groupId)")

        // Ensure WebSocket is connected
        if webSocketTask == nil {
            print("🔌 WebSocket is nil, creating new connection...")
            // ✅ FORCE development server for now (UserDefaults might not be set yet)
            let storedUrl = UserDefaults.standard.string(forKey: "flutter.ptt_server_url")
            let serverUrl = storedUrl ?? "wss://ptt.visionvivante.in" // Default to prod
            print("🔗 Stored URL for transmit: \(storedUrl ?? "nil"), Using: \(serverUrl)")
            
            guard let url = URL(string: serverUrl) else { 
                print("❌ Invalid PTT server URL: \(serverUrl)")
                return 
            }
            webSocketTask = urlSession.webSocketTask(with: url)
            webSocketTask?.resume()
            print("📡 Sent register message for userId: \(userId)")
            sendMessage(["type": "register", "userId": userId])
            print("📡 Sent switch message to group: \(groupId)")
            sendMessage(["type": "switch", "newGroupId": groupId])
            receiveNextMessage()
        } else {
            print("♻️ Reusing existing WebSocket connection")
            print("📡 Sent switch message to group: \(groupId)")
            sendMessage(["type": "switch", "newGroupId": groupId])
        }

        if isAudioSessionActive {
            print("🎙️ Session already active. Starting to record audio chunks...")
            startRecordingChunk()

            chunkTimer?.invalidate()
            chunkTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
                self?.flushAndContinueRecording()
            }
            print("⏱️ Chunk timer started (1.5s interval)")
        } else {
            print("⏳ Waiting for Audio Session to activate before recording...")
        }
    }

    private func startRecordingChunk() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileUrl = tempDir.appendingPathComponent("tx_\(Date().timeIntervalSince1970).m4a")
        currentRecordFileUrl = fileUrl

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileUrl, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            print("🎙️ NativePTTPlayer: Started recording chunk to \(fileUrl.lastPathComponent)")
        } catch {
            print("❌ NativePTTPlayer: Failed to start recording - \(error)")
        }
    }

    private func flushAndContinueRecording() {
        guard isTransmitting else { return }
        audioRecorder?.stop()
        if let fileUrl = currentRecordFileUrl {
            sendAudioChunk(fileUrl: fileUrl)
        }
        startRecordingChunk()
    }

    func stopTransmitting() {
        isTransmitting = false
        chunkTimer?.invalidate()
        chunkTimer = nil
        audioRecorder?.stop()
        if let fileUrl = currentRecordFileUrl {
            sendAudioChunk(fileUrl: fileUrl)
        }
        audioRecorder = nil
        currentRecordFileUrl = nil
        print("🎙️ NativePTTPlayer: Stopped transmitting")
    }

    private func sendAudioChunk(fileUrl: URL) {
        guard let groupId = currentGroupId else { return }
        let userId = UserDefaults.standard.string(forKey: "flutter.ptt_user_id") ?? ""
        
        do {
            let data = try Data(contentsOf: fileUrl)
            if data.isEmpty { return }
            
            let base64String = data.base64EncodedString()
            let msg: [String: Any] = [
                "type": "audio",
                "groupId": groupId,
                "sender": userId,
                "chunk": base64String
            ]
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: msg),
               let str = String(data: jsonData, encoding: .utf8) {
                webSocketTask?.send(.string(str)) { error in
                    if let error = error {
                        print("❌ NativePTTPlayer: Failed to send audio chunk - \(error)")
                    } else {
                        print("📤 NativePTTPlayer: Sent audio chunk (\(data.count) bytes)")
                    }
                }
            }
            
            // Clean up file
            try FileManager.default.removeItem(at: fileUrl)
        } catch {
            print("❌ NativePTTPlayer: Failed to read/send chunk - \(error)")
        }
    }

    // URLSessionWebSocketDelegate
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
        print("✅ NativePTTPlayer: WebSocket connected")
        // ⚡ If the PTT session was already active (consecutive push), kick off the queue now.
        DispatchQueue.main.async {
            self.forceStartIfSessionActive()
        }
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
            print("⏱️ Audio queue empty, waiting 3.5s before ending session...")
            DispatchQueue.main.async {
                self.endTransactionTimer?.invalidate()
                self.endTransactionTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { _ in
                    print("⏰ Timer expired, posting PTTAudioFinished notification")
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
  var pendingJoinChannelUUID: UUID? // Used to deduplicate rapid joinChannel calls

  // 🔑 Tracks if the app has ever been in the foreground during this process lifetime.
  // false = app was just woken from killed state by a VoIP/PTT push
  // true  = app was backgrounded by user (Home button) — PTT works silently
  var hasBeenInForeground = false

  // 📻 Once user accepts/declines the first CallKit screen, this stays TRUE
  // so all subsequent PTT pushes in the same session skip the CallKit UI
  // and just play audio silently. Resets when the full audio session ends.
  var isPTTKilledSessionActive = false
  
  // ✅ Helper function to generate UUID from groupId
  func channelUUIDFromGroupId(_ groupId: String) -> UUID {
    let md5 = Insecure.MD5.hash(data: Data(groupId.utf8))
    let hex = md5.compactMap { String(format: "%02x", $0) }.joined()
    let formatted = "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20).prefix(12))".uppercased()
    let finalUUID = UUID(uuidString: formatted) ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    print("📱 Channel UUID: \(groupId) -> \(finalUUID)")
    return finalUUID
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    hasBeenInForeground = true
    super.applicationDidBecomeActive(application)
  }

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
        NotificationCenter.default.addObserver(forName: NSNotification.Name("PTTAudioFinished"), object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            // End PushToTalk remote participant
            if let manager = self.channelManager as? PTChannelManager, let activeUUID = manager.activeChannelUUID {
                print("🛑 Ending PTT Active Remote Participant")
                manager.setActiveRemoteParticipant(nil, channelUUID: activeUUID, completionHandler: nil)
            }
            // ✅ DON'T auto-end CallKit call — let user dismiss or use talk button to reply
            // Only end it if no action is taken within 45 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 45.0) { [weak self] in
                guard let self = self, let uuid = self.activeCallUUID else { return }
                self.endPTTCallKitCall(uuid: uuid)
            }
            // 🔄 Reset the killed session flag so next fresh kill shows the call screen again
            self.isPTTKilledSessionActive = false
            print("🔄 PTT killed session ended — next kill will show call screen again")
        }

        PTChannelManager.channelManager(delegate: self, restorationDelegate: self) { manager, error in
            if let error = error {
                print("❌ Failed to initialize PTChannelManager: \(error)")
            } else if let manager = manager {
                self.channelManager = manager
                
                if let activeUUID = manager.activeChannelUUID {
                    print("✅ Already joined PTT Channel: \(activeUUID)")
                } else {
                    print("📻 Ready to join PTT channels dynamically.")
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
        } else if call.method == "joinChannel" {
          // ✅ Tell the iOS PushToTalk framework which channel we are active in
          if let args = call.arguments as? [String: Any], let groupId = args["groupId"] as? String {
              let newUUID = self.channelUUIDFromGroupId(groupId)
              
              if #available(iOS 16.0, *) {
                  let descriptor = PTChannelDescriptor(name: "Walkie-Talkie", image: nil)
                  
                  if let manager = self.channelManager as? PTChannelManager {
                      // Deduplicate rapid rapid calls from Flutter that happen before the framework updates
                      if self.pendingJoinChannelUUID == newUUID {
                          print("✅ Already in the process of joining: \(newUUID)")
                          result(nil)
                          return
                      }
                      
                      self.pendingJoinChannelUUID = newUUID

                      // Apple PushToTalk daemon has a known bug where it keeps a "zombie" lock on a channel
                      // from a previous app session, even if `activeChannelUUID` is locally nil!
                      // To fix Code=2 (channelLimitReached), we must FORCE the daemon to drop any channel it holds.
                      
                      if let oldUUID = manager.activeChannelUUID {
                          manager.leaveChannel(channelUUID: oldUUID)
                      }
                      // ALWAYS forcefully leave the newUUID as well just in case the daemon holds a zombie lock on it
                      manager.leaveChannel(channelUUID: newUUID)

                      // Now wait 1 full second for the iOS daemon to process the leaves, then join safely.
                      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                          // Ensure the user hasn't switched to a third group during the delay
                          if self.pendingJoinChannelUUID == newUUID {
                              manager.requestJoinChannel(channelUUID: newUUID, descriptor: descriptor)
                              print("📻 Native PTT Framework Joined Channel: \(newUUID)")
                          }
                      }
                  }
              }
          }
          result(nil)
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
    
    // ✅ CRITICAL: Store the groupId so the talk button knows where to send replies
    if !groupId.isEmpty {
        NativePTTPlayer.shared.currentGroupId = groupId
        NativePTTPlayer.shared.startBackgroundReceive(groupId: groupId)
        // ✅ FIX: On iOS < 16 (PushKit path) there is no PTT framework didActivate callback.
        // We must manually signal the audio session is ready after a short delay
        // so processQueue() can start playing the received chunks.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NativePTTPlayer.shared.sessionDidActivate()
        }
    }

    // ✅ Also notify Flutter that VoIP push was received (for when it resumes)
    sendVoIPPushToFlutter(payloadData)
  }

  // ─────────────────────────────────────────────────────
  // MARK: - CallKit for PTT (when app is killed)
  // ─────────────────────────────────────────────────────

  // Shows a CallKit incoming-call screen — the ONLY reliable way to wake a force-killed app.
  // Audio plays through NativePTTPlayer immediately; CallKit is auto-ended when audio finishes.
  private func reportPTTCallKitCall(senderName: String, groupId: String) {

    // ✅ CRITICAL: Store the groupId so the talk button knows where to send replies
    if !groupId.isEmpty {
        NativePTTPlayer.shared.currentGroupId = groupId
    }

    // 📻 If already in a killed-session (user saw & dismissed the first call screen),
    // ALL subsequent pushes just play audio silently — no new call screen!
    if isPTTKilledSessionActive {
        print("📻 PTT session already active — playing audio silently (no new call screen)")
        if !groupId.isEmpty {
            NativePTTPlayer.shared.startBackgroundReceive(groupId: groupId)
        }
        return
    }

    // 🔒 If a CallKit call is still showing (user hasn't acted yet), don't create a second one.
    if activeCallUUID != nil {
        print("⚠️ CallKit call already showing — starting audio for new group silently")
        if !groupId.isEmpty {
            NativePTTPlayer.shared.startBackgroundReceive(groupId: groupId)
        }
        return
    }

    // ✅ First push in this killed session — show the call screen
    isPTTKilledSessionActive = true
    let uuid = UUID()
    activeCallUUID = uuid

    let config = CXProviderConfiguration(localizedName: "Walkie-Talkie")
    config.supportsVideo = false
    config.maximumCallsPerCallGroup = 1
    config.supportedHandleTypes = [.generic]
    config.iconTemplateImageData = nil
    callProvider = CXProvider(configuration: config)
    callProvider?.setDelegate(self, queue: nil)

    let update = CXCallUpdate()
    update.remoteHandle = CXHandle(type: .generic, value: senderName)
    update.hasVideo = false
    update.localizedCallerName = "📻 \(senderName)"
    update.supportsHolding = false
    update.supportsDTMF = false
    update.supportsGrouping = false
    update.supportsUngrouping = false

    callProvider?.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
      guard let self = self else { return }
      if let error = error {
        print("❌ PTT CallKit failed: \(error.localizedDescription)")
        // Fallback: try NativePTTPlayer anyway
        if !groupId.isEmpty {
          NativePTTPlayer.shared.startBackgroundReceive(groupId: groupId)
          self.activateAudioSessionForPTT()
          NativePTTPlayer.shared.sessionDidActivate()
        }
      } else {
        print("✅ PTT CallKit call reported — waking killed app for audio!")
        // Activate audio and start NativePTTPlayer
        self.activateAudioSessionForPTT()
        if !groupId.isEmpty {
          NativePTTPlayer.shared.startBackgroundReceive(groupId: groupId)
        }
        // Give NativePTTPlayer 1 second to connect, then force-start if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
          NativePTTPlayer.shared.sessionDidActivate()
        }
        // ✅ Extend auto-end timeout to 60s to give user time to reply
        DispatchQueue.main.asyncAfter(deadline: .now() + 60.0) { [weak self] in
          guard let self = self, let uuid = self.activeCallUUID else { return }
          self.endPTTCallKitCall(uuid: uuid)
        }
      }
    }
  }

  private func endPTTCallKitCall(uuid: UUID) {
    guard activeCallUUID == uuid else { return } // already ended
    activeCallUUID = nil
    let endAction = CXEndCallAction(call: uuid)
    let transaction = CXTransaction(action: endAction)
    callController.request(transaction) { error in
      if let e = error { print("⚠️ PTT CallKit end error: \(e)") }
      else { print("✅ PTT CallKit call auto-ended after audio finished") }
    }
  }

  // ─────────────────────────────────────────────────────
  // MARK: - Audio Session Helpers
  // ─────────────────────────────────────────────────────

  private func activateAudioSessionForPTT() {
    do {
      let session = AVAudioSession.sharedInstance()
      // ✅ FIX: Use .playback category for LOUD speaker output.
      // .playAndRecord with .voiceChat mode applies AGC + noise suppression that
      // intentionally reduces output volume by ~60%. For PTT receive-only, .playback is correct.
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try session.setActive(true)
      try session.overrideOutputAudioPort(.speaker) // 🔊 Force loud speaker
      print("✅ AVAudioSession activated for PTT delivery — full volume speaker")
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
      // ✅ FIX: Do NOT call setCategory here — that resets the whole AVAudioSession
      // and can interfere with the Flutter-managed session on iPhone 12 Pro.
      // Instead, just override the output port. This is a lightweight, non-destructive call.
      // Only .playAndRecord category supports this override. If it fails, we silently ignore.
      if session.category == .playAndRecord {
        try session.setActive(true)
        try session.overrideOutputAudioPort(.speaker)
        print("🔊 Speaker output overridden (lightweight, session category preserved)")
      }
    } catch {
      // Silently ignore harmless errors like -50 (kAudioSessionBadParam) 
      // which happen if category is .playback, since .playback already uses the speaker.
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

  // User tapped ANSWER on the Walkie-Talkie call screen
  func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    print("📞 User answered PTT CallKit call — opening app")
    // The audio is already playing via NativePTTPlayer.
    // Notify Flutter so it can open/foreground the app if needed.
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "ptt/voip", binaryMessenger: controller.binaryMessenger)
      channel.invokeMethod("onCallAnswered", arguments: nil)
    }
    action.fulfill()
  }

  // User tapped DECLINE or call timed out.
  // 💡 IMPORTANT: We do NOT stop audio here! The voice message always plays to completion.
  // Declining just dismisses the UI — isPTTKilledSessionActive stays true so
  // future pushes also play silently without showing another call screen.
  func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    print("🛑 PTT CallKit call UI dismissed — audio keeps playing silently")
    activeCallUUID = nil // Clear UUID so auto-end timer won't fire again
    // ❌ Do NOT call NativePTTPlayer.shared.disconnect() here!
    // ❌ Do NOT reset isPTTKilledSessionActive here!
    // Audio will auto-stop when PTTAudioFinished fires, which THEN resets everything.
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
        
        // 🚨 DEBUG: Show a local notification so we know the app woke up but dropped the audio!
        let content = UNMutableNotificationContent()
        content.title = "App Woke Up (Token Only)"
        content.body = "Received PushToTalk token update in background. Audio blocked."
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    func incomingPushResult(channelManager: PTChannelManager, channelUUID: UUID, pushPayload: [String : Any]) -> PTPushResult {
        print("📨 PTT Push Received: \(pushPayload)")
        print("📱 Channel UUID: \(channelUUID)")  // ✅ Log the channelUUID

        let groupId = pushPayload["groupId"] as? String ?? ""
        let senderName = pushPayload["senderName"] as? String ?? "Walkie-Talkie"
        NativePTTPlayer.shared.currentGroupId = groupId // ✅ Cache for replying
        
        // ✅ Generate expected channelUUID from groupId
        let expectedChannelUUID = channelUUIDFromGroupId(groupId)
        print("🔑 Expected channelUUID from groupId: \(expectedChannelUUID)")
        print("🔑 Actual channelUUID from push: \(channelUUID)")
        
        if channelUUID != expectedChannelUUID {
            print("⚠️  channelUUID mismatch! This might cause issues.")
        }

        // ✅ Start background audio playback
        // The PTT framework (iOS 16+) wakes the app on its own. CallKit is NOT needed.
        // Whether the app was killed or backgrounded, just connect and play audio.
        print("🔊 PTT push — will play audio and show system UI")
        
        DispatchQueue.main.async {
            if UIApplication.shared.applicationState == .active {
                print("🛑 App is in FOREGROUND — skipping NativePTTPlayer to avoid double audio!")
            } else {
                if !groupId.isEmpty {
                    NativePTTPlayer.shared.startBackgroundReceive(groupId: groupId)
                    // Give the WebSocket 0.5s to connect before force-starting the queue.
                    // The real activation also comes from channelManager(_:didActivate:) below.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        // ✅ FIX: Only trigger fallback if the system didn't already activate the session!
                        // Overriding the session while Apple's Walkie-Talkie is playing causes the audio to mute.
                        if !NativePTTPlayer.shared.isAudioSessionActive {
                            NativePTTPlayer.shared.sessionDidActivate()
                        }
                    }
                }
            }
        }

        // Notify Flutter (with UserDefaults fallback for when Flutter isn't ready)
        sendVoIPPushToFlutter(pushPayload)

        // ✅ Return activeRemoteParticipant to keep PTT session alive and show system UI
        let participant = PTParticipant(name: senderName, image: nil)
        return .activeRemoteParticipant(participant)
    }
    
    func channelDescriptor(restoredChannelUUID channelUUID: UUID) -> PTChannelDescriptor {
        return PTChannelDescriptor(name: "Walkie-Talkie", image: nil)
    }
    
        
    func channelManager(_ channelManager: PTChannelManager, didActivate audioSession: AVAudioSession) {
        print("🎙️ PTT Audio Session Activated")
        NativePTTPlayer.shared.sessionDidActivate(audioSession: audioSession)
    }
    
    func channelManager(_ channelManager: PTChannelManager, didDeactivate audioSession: AVAudioSession) {
        print("🎙️ PTT Audio Session Deactivated")
        NativePTTPlayer.shared.disconnect()
    }

    func channelManager(_ channelManager: PTChannelManager, didJoinChannel channelUUID: UUID, reason: PTChannelJoinReason) {
        print("🎙️ Joined PTT Channel")
    }
    
    func channelManager(_ channelManager: PTChannelManager, didLeaveChannel channelUUID: UUID, reason: PTChannelLeaveReason) {
        print("🎙️ Left PTT Channel: \(channelUUID)")
    }
    
    func channelManager(_ channelManager: PTChannelManager, channelUUID: UUID, didBeginTransmittingFrom source: PTChannelTransmitRequestSource) {
        print("🎙️ Began Transmitting (source: \(source.rawValue))")
        
        // ✅ Get the groupId from either cached value or try to retrieve from pending push
        var groupId = NativePTTPlayer.shared.currentGroupId
        print("📍 Current groupId in memory: \(groupId ?? "nil")")
        
        if groupId == nil || groupId!.isEmpty {
            // ⚠️ Fallback: Try to get groupId from the pending VoIP payload
            if let payload = UserDefaults.standard.dictionary(forKey: "pending_voip_payload"),
               let gId = payload["groupId"] as? String {
                groupId = gId
                NativePTTPlayer.shared.currentGroupId = gId
                print("🔄 Retrieved groupId from pending payload: \(gId)")
            } else {
                print("⚠️ No pending payload found in UserDefaults")
            }
        }
        
        if let groupId = groupId, !groupId.isEmpty {
            print("✅ Starting transmission to group: \(groupId)")
            NativePTTPlayer.shared.startTransmitting(groupId: groupId)
        } else {
            print("❌ Cannot transmit: No groupId available!")
            print("💡 Tip: Make sure a PTT message was received before trying to reply")
        }
    }
    
    func channelManager(_ channelManager: PTChannelManager, channelUUID: UUID, didEndTransmittingFrom source: PTChannelTransmitRequestSource) {
        print("🎙️ Ended Transmitting (source: \(source.rawValue))")
        NativePTTPlayer.shared.stopTransmitting()
        
        // Hide Walkie-Talkie UI immediately after user releases Talk button
        // print("🛑 Hiding Walkie-Talkie UI by leaving channel...")
        // channelManager.leaveChannel(channelUUID: channelUUID)
    }
    
    // Duplicate didLeaveChannel removed.
    
    func channelManager(_ channelManager: PTChannelManager, failedToJoinChannel channelUUID: UUID, error: Error) {
        print("❌ Failed to join PTT Channel: \(error)")
    }
}
// import UIKit
// import Flutter
// import Firebase
// import FirebaseMessaging
// import AVFoundation
// import PushKit
// import CallKit
// import PushToTalk
// import Foundation

// // ─────────────────────────────────────────────────────────────────────────────
// // MARK: - NativePTTPlayer
// //
// // Pure-Swift background WebSocket + audio player/recorder.
// // Runs entirely without Flutter — works when phone is locked/app suspended.
// //
// // Thread-safety model:
// //   All mutable state is confined to `queue` (a private serial DispatchQueue).
// //   Public methods dispatch onto `queue` internally.
// //   AVAudioPlayerDelegate callbacks are re-dispatched onto `queue` before
// //   touching any shared state.
// // ─────────────────────────────────────────────────────────────────────────────
// final class NativePTTPlayer: NSObject {

//     static let shared = NativePTTPlayer()
//     private override init() { super.init() }

//     // Serial queue — ALL mutable state must be accessed here
//     private let queue = DispatchQueue(label: "com.ptt.player", qos: .userInitiated)

//     // ── WebSocket ──────────────────────────────────────────────────────────
//     private var webSocketTask: URLSessionWebSocketTask?
//     private lazy var urlSession: URLSession = {
//         let config = URLSessionConfiguration.default
//         config.timeoutIntervalForRequest = 30
//         return URLSession(configuration: config,
//                           delegate: self,
//                           delegateQueue: OperationQueue())   // background thread
//     }()

//     // ── Receive-side state ─────────────────────────────────────────────────
//     private var isReceiving = false
//     private var audioQueue: [Data] = []          // chunks ready to play (session active)
//     private var pendingAudioQueue: [Data] = []   // chunks arrived before session activated
//     private var isPlaying = false
//     private var audioPlayer: AVAudioPlayer?
//     private var endTransactionTimer: Timer?         // always fired on main thread

//     // ── Session state ──────────────────────────────────────────────────────
//     /// Set to true only after PTT/AVAudio session is fully activated.
//     private(set) var isAudioSessionActive = false

//     /// Incremented every time a new receive session starts.
//     /// didDeactivate captures this value; if it changed by the time it fires,
//     /// a new session is already running — the disconnect is skipped.
//     private var sessionGeneration: Int = 0

//     // ── Transmit-side state ────────────────────────────────────────────────
//     var currentGroupId: String?
//     private var isTransmitting = false
//     private var audioRecorder: AVAudioRecorder?
//     private var chunkTimer: Timer?                  // always fired on main thread
//     private var currentRecordFileUrl: URL?

//     // ─────────────────────────────────────────────────────────────────────
//     // MARK: - Connection helpers
//     // ─────────────────────────────────────────────────────────────────────

//     private func resolvedServerURL() -> URL? {
//         let stored = UserDefaults.standard.string(forKey: "flutter.ptt_server_url")
//         let raw = stored ?? "wss://ptt.visionvivante.in"
//         return URL(string: raw)
//     }

//     private func myUserId() -> String {
//         return UserDefaults.standard.string(forKey: "flutter.ptt_user_id") ?? ""
//     }

//     // Open WebSocket (must be called on `queue`)
//     private func openWebSocket() {
//         guard webSocketTask == nil else { return }
//         guard let url = resolvedServerURL() else {
//             print("❌ NativePTTPlayer: Invalid server URL")
//             return
//         }
//         webSocketTask = urlSession.webSocketTask(with: url)
//         webSocketTask?.resume()
//         print("📡 NativePTTPlayer: WebSocket opening → \(url)")
//     }

//     private func sendJSON(_ dict: [String: Any]) {
//         guard let data = try? JSONSerialization.data(withJSONObject: dict),
//               let str  = String(data: data, encoding: .utf8) else { return }
//         webSocketTask?.send(.string(str)) { error in
//             if let e = error { print("⚠️ NativePTTPlayer send error: \(e)") }
//         }
//     }

//     // ─────────────────────────────────────────────────────────────────────
//     // MARK: - Receive path
//     // ─────────────────────────────────────────────────────────────────────

//     /// Called when a VoIP / PTT push arrives. Connects and starts streaming audio.
//     func startBackgroundReceive(groupId: String) {
//         queue.async { [weak self] in
//             guard let self else { return }

//             let userId = self.myUserId()
//             guard !userId.isEmpty else {
//                 print("⚠️ NativePTTPlayer: No userId — cannot connect")
//                 return
//             }

//             // Ignore duplicate pushes while already receiving the same group
//             if self.isReceiving && self.webSocketTask != nil {
//                 print("✅ NativePTTPlayer: Already receiving — ignoring duplicate push")
//                 return
//             }

//             // Tear down any stale connection without resetting session-active flag
//             self._softDisconnect()
//             self.isReceiving = true
//             self.currentGroupId = groupId
//             self.sessionGeneration += 1   // new session — invalidates any pending didDeactivate

//             self.openWebSocket()
//             self.sendJSON(["type": "register", "userId": userId])
//             self.sendJSON(["type": "switch",   "newGroupId": groupId])
//             self.scheduleReceive()

//             // Safety auto-disconnect after 45 s
//             self.queue.asyncAfter(deadline: .now() + 45) { [weak self] in
//                 self?._disconnect()
//             }
//             print("🔊 NativePTTPlayer: Receive started for group \(groupId) as \(userId)")
//         }
//     }

//     private func scheduleReceive() {
//         // Must be called on `queue`
//         webSocketTask?.receive { [weak self] result in
//             guard let self else { return }
//             self.queue.async {
//                 guard self.isReceiving else { return }
//                 switch result {
//                 case .success(let message):
//                     // A new chunk arrived — cancel any pending "queue empty" shutdown
//                     DispatchQueue.main.async {
//                         self.endTransactionTimer?.invalidate()
//                         self.endTransactionTimer = nil
//                     }
//                     if case .string(let text) = message {
//                         self.handleTextMessage(text)
//                     }
//                     self.scheduleReceive()      // keep listening

//                 case .failure(let error):
//                     print("⚠️ NativePTTPlayer receive error: \(error.localizedDescription)")
//                     self.isReceiving = false
//                 }
//             }
//         }
//     }

//     private func handleTextMessage(_ text: String) {
//         // Called on `queue`
//         guard
//             let data   = text.data(using: .utf8),
//             let json   = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
//             let type   = json["type"]  as? String, type == "audio",
//             let chunk  = json["chunk"] as? String,
//             let audio  = Data(base64Encoded: chunk)
//         else { return }

//         // Discard our own echo
//         let senderId = json["sender"] as? String ?? ""
//         if !senderId.isEmpty && senderId == myUserId() {
//             print("🔇 NativePTTPlayer: Ignoring own audio echo")
//             return
//         }

//         print("🔊 NativePTTPlayer: Queuing \(audio.count) bytes")
//         if isAudioSessionActive {
//             audioQueue.append(audio)
//         } else {
//             // Session not ready yet — hold in pending queue, will be flushed by sessionDidActivate
//             pendingAudioQueue.append(audio)
//             print("⏳ NativePTTPlayer: Session not active — held in pending queue (\(pendingAudioQueue.count) chunks)")
//             return
//         }
//         processQueue()
//     }

//     // ─────────────────────────────────────────────────────────────────────
//     // MARK: - Audio session activation
//     // ─────────────────────────────────────────────────────────────────────

//     /// Called by AppDelegate when AVAudioSession is fully ready.
//     /// - Parameter audioSession: Pass the system-provided session from PTT framework;
//     ///   pass nil to configure the session locally (PushKit / iOS < 16 path).
//     func sessionDidActivate(audioSession: AVAudioSession? = nil) {
//         queue.async { [weak self] in
//             guard let self else { return }

//             self.isAudioSessionActive = true

//             // Flush any chunks that arrived before the session was ready
//             if !self.pendingAudioQueue.isEmpty {
//                 print("⚡ NativePTTPlayer: Flushing \(self.pendingAudioQueue.count) pending chunks into play queue")
//                 self.audioQueue.insert(contentsOf: self.pendingAudioQueue, at: 0)
//                 self.pendingAudioQueue.removeAll()
//             }

//             if audioSession == nil {
//                 // Local (non-PTT-framework) path: configure ourselves
//                 let s = AVAudioSession.sharedInstance()
//                 do {
//                     try s.setCategory(.playAndRecord, mode: .default,
//                                       options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth])
//                     try s.setActive(true)
//                     try s.overrideOutputAudioPort(.speaker)
//                     print("🔊 NativePTTPlayer: Local audio session configured for speaker")
//                 } catch {
//                     print("❌ NativePTTPlayer: Audio session config error — \(error)")
//                 }
//             } else {
//                 // Apple PTT framework owns the session; do NOT modify category/port
//                 print("🔊 NativePTTPlayer: System PTT audio session active — using Apple routing")
//             }

//             self.processQueue()

//             // If transmit was requested before the session activated, start now
//             if self.isTransmitting && self.audioRecorder == nil {
//                 self.startRecordingChunk()
//                 self.scheduleChunkTimer()
//             }
//         }
//     }

//     /// Force-process the queue immediately if session is already active
//     /// (e.g. consecutive push while session is still open).
//     func forceStartIfSessionActive() {
//         queue.async { [weak self] in
//             guard let self, self.isAudioSessionActive else { return }
//             print("⚡ NativePTTPlayer: Session already active — force-starting queue")
//             self.processQueue()
//         }
//     }

//     // ─────────────────────────────────────────────────────────────────────
//     // MARK: - Audio playback queue
//     // ─────────────────────────────────────────────────────────────────────

//     // Must be called on `queue`
//     private func processQueue() {
//         guard isAudioSessionActive, !isPlaying, !audioQueue.isEmpty else {
//             if !isAudioSessionActive {
//                 print("⏳ NativePTTPlayer: Queue waiting — session not active yet")
//             }
//             return
//         }
//         isPlaying = true
//         let data = audioQueue.removeFirst()
//         playChunk(data: data)
//     }

//     private func playChunk(data: Data) {
//         // Must be called on `queue`
//         let tempURL = FileManager.default.temporaryDirectory
//             .appendingPathComponent(UUID().uuidString + ".m4a")
//         do {
//             try data.write(to: tempURL)
//             let player = try AVAudioPlayer(contentsOf: tempURL)
//             player.delegate = self
//             player.volume = 1.0
//             player.prepareToPlay()
//             player.play()
//             audioPlayer = player
//             // Temp file will be deleted in audioPlayerDidFinishPlaying
//             print("▶️ NativePTTPlayer: Playing chunk (\(data.count) bytes)")
//         } catch {
//             print("❌ NativePTTPlayer: Playback error — \(error)")
//             deleteTempFile(at: tempURL)
//             isPlaying = false
//             processQueue()  // skip to next
//         }
//     }

//     private func deleteTempFile(at url: URL) {
//         try? FileManager.default.removeItem(at: url)
//     }

//     // ─────────────────────────────────────────────────────────────────────
//     // MARK: - Transmit path
//     // ─────────────────────────────────────────────────────────────────────

//     func startTransmitting(groupId: String) {
//         queue.async { [weak self] in
//             guard let self else { return }

//             let userId = self.myUserId()
//             guard !userId.isEmpty else {
//                 print("❌ Cannot transmit: No userId")
//                 return
//             }

//             self.isTransmitting = true
//             self.currentGroupId = groupId

//             if self.webSocketTask == nil {
//                 self.openWebSocket()
//                 self.sendJSON(["type": "register",   "userId": userId])
//                 self.sendJSON(["type": "switch",     "newGroupId": groupId])
//                 self.scheduleReceive()
//             } else {
//                 // Reuse existing connection but ensure we're on the right group
//                 self.sendJSON(["type": "switch", "newGroupId": groupId])
//             }

//             guard self.isAudioSessionActive else {
//                 print("⏳ NativePTTPlayer: Waiting for session to activate before recording")
//                 return
//             }
//             self.startRecordingChunk()
//             self.scheduleChunkTimer()
//         }
//     }

//     func stopTransmitting() {
//         queue.async { [weak self] in
//             guard let self else { return }
//             self.isTransmitting = false
//             DispatchQueue.main.async {
//                 self.chunkTimer?.invalidate()
//                 self.chunkTimer = nil
//             }
//             self.audioRecorder?.stop()
//             if let url = self.currentRecordFileUrl {
//                 self.sendAudioChunk(fileURL: url)
//             }
//             self.audioRecorder = nil
//             self.currentRecordFileUrl = nil
//             print("🎙️ NativePTTPlayer: Transmit stopped")
//         }
//     }

//     // Must be called on `queue`
//     private func startRecordingChunk() {
//         let url = FileManager.default.temporaryDirectory
//             .appendingPathComponent("tx_\(Date().timeIntervalSince1970).m4a")
//         currentRecordFileUrl = url

//         // 16 kHz mono AAC — appropriate for voice PTT, ~60% smaller than 44.1 kHz
//         let settings: [String: Any] = [
//             AVFormatIDKey:              Int(kAudioFormatMPEG4AAC),
//             AVSampleRateKey:            16000.0,
//             AVNumberOfChannelsKey:      1,
//             AVEncoderAudioQualityKey:   AVAudioQuality.medium.rawValue
//         ]
//         do {
//             audioRecorder = try AVAudioRecorder(url: url, settings: settings)
//             audioRecorder?.prepareToRecord()
//             audioRecorder?.record()
//             print("🎙️ NativePTTPlayer: Recording chunk → \(url.lastPathComponent)")
//         } catch {
//             print("❌ NativePTTPlayer: Recorder init failed — \(error)")
//         }
//     }

//     // Must be called on main thread (Timer requirement)
//     private func scheduleChunkTimer() {
//         DispatchQueue.main.async { [weak self] in
//             guard let self else { return }
//             self.chunkTimer?.invalidate()
//             self.chunkTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
//                 self?.queue.async { self?.flushAndContinueRecording() }
//             }
//         }
//     }

//     // Must be called on `queue`
//     private func flushAndContinueRecording() {
//         guard isTransmitting else { return }
//         audioRecorder?.stop()
//         if let url = currentRecordFileUrl {
//             sendAudioChunk(fileURL: url)
//         }
//         startRecordingChunk()
//     }

//     private func sendAudioChunk(fileURL: URL) {
//         // Must be called on `queue`
//         guard let groupId = currentGroupId else { return }
//         let userId = myUserId()
//         defer { try? FileManager.default.removeItem(at: fileURL) }

//         guard
//             let data = try? Data(contentsOf: fileURL),
//             !data.isEmpty
//         else { return }

//         let msg: [String: Any] = [
//             "type":    "audio",
//             "groupId": groupId,
//             "sender":  userId,
//             "chunk":   data.base64EncodedString()
//         ]
//         sendJSON(msg)
//         print("📤 NativePTTPlayer: Sent \(data.count) bytes to group \(groupId)")
//     }

//     // ─────────────────────────────────────────────────────────────────────
//     // MARK: - Disconnect helpers
//     // ─────────────────────────────────────────────────────────────────────

//     /// Soft-disconnect: closes WebSocket but preserves `isAudioSessionActive`.
//     /// Use between consecutive pushes — iOS may not re-fire didActivate.
//     func softDisconnect() {
//         queue.async { [weak self] in self?._softDisconnect() }
//     }

//     // Must be called on `queue`
//     private func _softDisconnect() {
//         isReceiving = false
//         isPlaying   = false
//         audioQueue.removeAll()
//         pendingAudioQueue.removeAll()
//         audioPlayer?.stop()
//         audioPlayer = nil
//         webSocketTask?.cancel(with: .normalClosure, reason: nil)
//         webSocketTask = nil
//         // Pending endTransactionTimer stays — it fires on main; cancel on main to be safe
//         DispatchQueue.main.async { [weak self] in
//             self?.endTransactionTimer?.invalidate()
//             self?.endTransactionTimer = nil
//         }
//         print("🔌 NativePTTPlayer: Soft-disconnected (session active flag preserved)")
//     }

//     var currentSessionGeneration: Int {
//         queue.sync { sessionGeneration }
//     }

//     /// Called by didDeactivate — only disconnects if no new session has started since.
//     func disconnectIfSessionStillValid(generation: Int) {
//         queue.async { [weak self] in
//             guard let self else { return }
//             guard self.sessionGeneration == generation else {
//                 print("⏭️ NativePTTPlayer: Ignoring stale didDeactivate (new session already running)")
//                 return
//             }
//             self._disconnect()
//         }
//     }

//     /// Full disconnect: resets ALL state including the session-active flag.
//     /// Call only when the PTT session has truly ended (didDeactivate).
//     func disconnect() {
//         queue.async { [weak self] in self?._disconnect() }
//     }

//     // Must be called on `queue`
//     private func _disconnect() {
//         _softDisconnect()
//         isAudioSessionActive = false
//         isTransmitting       = false
//         currentRecordFileUrl = nil
//         audioRecorder?.stop()
//         audioRecorder = nil
//         DispatchQueue.main.async { [weak self] in
//             self?.chunkTimer?.invalidate()
//             self?.chunkTimer = nil
//         }
//         print("🔌 NativePTTPlayer: Full disconnect — all state reset")
//     }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // MARK: - URLSessionWebSocketDelegate
// // ─────────────────────────────────────────────────────────────────────────────
// extension NativePTTPlayer: URLSessionWebSocketDelegate {

//     func urlSession(_ session: URLSession,
//                     webSocketTask: URLSessionWebSocketTask,
//                     didOpenWithProtocol protocol: String?) {
//         print("✅ NativePTTPlayer: WebSocket connected")
//         queue.async { [weak self] in
//             guard let self, self.isAudioSessionActive else { return }
//             self.processQueue()
//         }
//     }

//     func urlSession(_ session: URLSession,
//                     webSocketTask: URLSessionWebSocketTask,
//                     didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
//                     reason: Data?) {
//         print("🔌 NativePTTPlayer: WebSocket closed (\(closeCode.rawValue))")
//         queue.async { [weak self] in self?.isReceiving = false }
//     }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // MARK: - AVAudioPlayerDelegate
// // ─────────────────────────────────────────────────────────────────────────────
// extension NativePTTPlayer: AVAudioPlayerDelegate {

//     func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
//         // Delete the temp file the player was using
//         if let url = player.url { deleteTempFile(at: url) }

//         queue.async { [weak self] in
//             guard let self else { return }
//             self.isPlaying = false

//             if self.audioQueue.isEmpty {
//                 // Wait 3.5 s before ending the session (Android streams 1.5 s chunks)
//                 print("⏱️ Queue empty — waiting 3.5 s before ending PTT session")
//                 DispatchQueue.main.async {
//                     self.endTransactionTimer?.invalidate()
//                     self.endTransactionTimer = Timer.scheduledTimer(
//                         withTimeInterval: 3.5, repeats: false
//                     ) { [weak self] _ in
//                         guard let self else { return }
//                         print("⏰ PTTAudioFinished")
//                         NotificationCenter.default.post(
//                             name: .PTTAudioFinished, object: nil)
//                         self.queue.async { self.endTransactionTimer = nil }
//                     }
//                 }
//             } else {
//                 self.processQueue()
//             }
//         }
//     }

//     func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
//         print("❌ NativePTTPlayer: Decode error — \(error?.localizedDescription ?? "unknown")")
//         if let url = player.url { deleteTempFile(at: url) }
//         queue.async { [weak self] in
//             guard let self else { return }
//             self.isPlaying = false
//             self.processQueue()
//         }
//     }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // MARK: - Notification name
// // ─────────────────────────────────────────────────────────────────────────────
// extension Notification.Name {
//     static let PTTAudioFinished = Notification.Name("PTTAudioFinished")
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // MARK: - AppDelegate
// // ─────────────────────────────────────────────────────────────────────────────
// @main
// @objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate {

//     var callProvider: CXProvider?
//     var callController = CXCallController()
//     var activeCallUUID: UUID?
//     var channelManager: Any?     // PTChannelManager on iOS 16+

//     /// Tracks whether the CallKit "call screen" is currently visible for a killed-session PTT push.
//     /// Resets when audio finishes (PTTAudioFinished).
//     var isPTTKilledSessionActive = false

//     // ─────────────────────────────────────────────────────
//     // MARK: - UUID helper (deterministic from groupId)
//     // ─────────────────────────────────────────────────────

//     /// Produces a stable UUID from a groupId string using a simple but collision-safe approach.
//     func makeChannelUUID(from groupId: String) -> UUID {
//         // Use the lower 32 bits of a DJB2 hash (consistent across calls, no Int overflow)
//         var hash: UInt32 = 5381
//         for c in groupId.utf8 {
//             hash = hash &* 33 &+ UInt32(c)
//         }
//         let uuidString = String(format: "%08x-0000-4000-8000-000000000000", hash)
//         return UUID(uuidString: uuidString) ?? UUID()
//     }

//     // ─────────────────────────────────────────────────────
//     // MARK: - App lifecycle
//     // ─────────────────────────────────────────────────────

//     override func application(
//         _ application: UIApplication,
//         didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
//     ) -> Bool {

//         FirebaseApp.configure()
//         UNUserNotificationCenter.current().delegate = self
//         application.registerForRemoteNotifications()
//         GeneratedPluginRegistrant.register(with: self)

//         setupCallKit()
//         setupPTTFramework()
//         setupFlutterChannels()

//         return super.application(application, didFinishLaunchingWithOptions: launchOptions)
//     }

//     // ─────────────────────────────────────────────────────
//     // MARK: - CallKit setup
//     // ─────────────────────────────────────────────────────

//     private func setupCallKit() {
//         let config = CXProviderConfiguration(localizedName: "Walkie-Talkie")
//         config.supportsVideo     = false
//         config.maximumCallsPerCallGroup = 1
//         config.supportedHandleTypes    = [.generic]
//         callProvider = CXProvider(configuration: config)
//         callProvider?.setDelegate(self, queue: nil)
//     }

//     // ─────────────────────────────────────────────────────
//     // MARK: - PTT Framework / VoIP push setup
//     // ─────────────────────────────────────────────────────

//     private func setupPTTFramework() {
//         if #available(iOS 16.0, *) {
//             // Observe audio-finished to end the PTT session cleanly
//             NotificationCenter.default.addObserver(
//                 forName: .PTTAudioFinished, object: nil, queue: .main
//             ) { [weak self] _ in
//                 guard let self else { return }
//                 if let manager = self.channelManager as? PTChannelManager,
//                    let uuid   = manager.activeChannelUUID {
//                     manager.setActiveRemoteParticipant(nil, channelUUID: uuid,
//                                                        completionHandler: nil)
//                 }
//                 // Give user 45 s to reply before auto-ending the CallKit call
//                 DispatchQueue.main.asyncAfter(deadline: .now() + 45) { [weak self] in
//                     guard let self, let uuid = self.activeCallUUID else { return }
//                     self.endCallKitCall(uuid: uuid)
//                 }
//                 self.isPTTKilledSessionActive = false
//                 print("🔄 PTT killed session ended — next kill will show call screen again")
//             }

//             PTChannelManager.channelManager(delegate: self, restorationDelegate: self) { manager, error in
//                 if let error { print("❌ PTChannelManager init failed: \(error)"); return }
//                 guard let manager else { return }
//                 self.channelManager = manager

//                 if let active = manager.activeChannelUUID {
//                     print("✅ PTT channel already joined: \(active)")
//                 } else {
//                     let defaultUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
//                     let descriptor  = PTChannelDescriptor(name: "Walkie-Talkie", image: nil)
//                     manager.requestJoinChannel(channelUUID: defaultUUID, descriptor: descriptor)
//                     print("📻 Joined default PTT channel")
//                 }
//             }
//         } else {
//             // iOS < 16 — use PushKit VoIP pushes directly
//             let registry = PKPushRegistry(queue: .main)
//             registry.delegate         = self
//             registry.desiredPushTypes = [.voIP]
//         }
//     }

//     // ─────────────────────────────────────────────────────
//     // MARK: - Flutter method channels
//     // ─────────────────────────────────────────────────────

//     private func setupFlutterChannels() {
//         guard let controller = window?.rootViewController as? FlutterViewController else { return }
//         let messenger = controller.binaryMessenger

//         // Audio control channel
//         let audioChannel = FlutterMethodChannel(name: "custom.audio", binaryMessenger: messenger)
//         audioChannel.setMethodCallHandler { [weak self] call, result in
//             guard let self else { return result(FlutterMethodNotImplemented) }
//             switch call.method {
//             case "forceSpeaker":  self.forceSpeaker();              result(nil)
//             case "forceMic":      self.configureMicSession();       result(nil)
//             case "forceVideoChat":self.configureVideoChatSession(); result(nil)
//             default:              result(FlutterMethodNotImplemented)
//             }
//         }

//         // VoIP/PTT control channel
//         let voipChannel = FlutterMethodChannel(name: "ptt/voip", binaryMessenger: messenger)
//         voipChannel.setMethodCallHandler { call, result in
//             switch call.method {
//             case "getVoIPToken":
//                 result(UserDefaults.standard.string(forKey: "voip_token"))

//             case "getPendingVoIPPayload":
//                 result(UserDefaults.standard.dictionary(forKey: "pending_voip_payload"))

//             case "clearPendingVoIPPayload":
//                 UserDefaults.standard.removeObject(forKey: "pending_voip_payload")
//                 result(nil)

//             case "isAppInBackground":
//                 let state = UIApplication.shared.applicationState
//                 result(state == .background || state == .inactive)

//             default:
//                 result(FlutterMethodNotImplemented)
//             }
//         }
//     }

//     // ─────────────────────────────────────────────────────
//     // MARK: - PushKit VoIP delegate (iOS < 16)
//     // ─────────────────────────────────────────────────────

//     func pushRegistry(_ registry: PKPushRegistry,
//                       didUpdate pushCredentials: PKPushCredentials,
//                       for type: PKPushType) {
//         let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
//         print("📲 VoIP Push Token: \(token)")
//         UserDefaults.standard.set(token, forKey: "voip_token")
//         sendVoIPTokenToFlutter(token)
//     }

//     func pushRegistry(_ registry: PKPushRegistry,
//                       didReceiveIncomingPushWith payload: PKPushPayload,
//                       for type: PKPushType,
//                       completion: @escaping () -> Void) {
//         print("📨 PushKit VoIP push: \(payload.dictionaryPayload)")

//         let payloadDict = payload.dictionaryPayload
//         let groupId     = payloadDict["groupId"]    as? String ?? ""
//         let senderName  = payloadDict["senderName"] as? String ?? "PTT Message"

//         // MANDATORY on iOS 13+: report a call to CallKit immediately or Apple kills the app
//         let uuid   = UUID()
//         activeCallUUID = uuid
//         let update = CXCallUpdate()
//         update.remoteHandle      = CXHandle(type: .generic, value: senderName)
//         update.hasVideo          = false
//         update.localizedCallerName = senderName

//         callProvider?.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
//             guard let self else { completion(); return }
//             if let error {
//                 print("❌ CallKit report error: \(error)")
//             } else {
//                 // Auto-dismiss CallKit UI after 10 s — gives enough time for background audio
//                 DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
//                     self?.endCallKitCall(uuid: uuid)
//                 }
//             }
//             completion()
//         }

//         if !groupId.isEmpty {
//             NativePTTPlayer.shared.currentGroupId = groupId
//             activateAudioSession()
//             NativePTTPlayer.shared.startBackgroundReceive(groupId: groupId)
//             // iOS < 16 has no didActivate callback — signal manually after a short delay
//             DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                 NativePTTPlayer.shared.sessionDidActivate()
//             }
//         }

//         sendVoIPPushToFlutter(payloadDict)
//     }

//     // ─────────────────────────────────────────────────────
//     // MARK: - CallKit helpers
//     // ─────────────────────────────────────────────────────

//     private func reportPTTCallKitCall(senderName: String, groupId: String) {
//         if !groupId.isEmpty {
//             NativePTTPlayer.shared.currentGroupId = groupId
//         }

//         // Already showing a call screen — just play audio silently
//         if isPTTKilledSessionActive || activeCallUUID != nil {
//             print("📻 PTT session already showing — playing audio silently")
//             if !groupId.isEmpty {
//                 NativePTTPlayer.shared.startBackgroundReceive(groupId: groupId)
//             }
//             return
//         }

//         isPTTKilledSessionActive = true
//         let uuid = UUID()
//         activeCallUUID = uuid

//         let update = CXCallUpdate()
//         update.remoteHandle        = CXHandle(type: .generic, value: senderName)
//         update.localizedCallerName = "📻 \(senderName)"
//         update.hasVideo            = false
//         update.supportsHolding     = false
//         update.supportsDTMF        = false
//         update.supportsGrouping    = false
//         update.supportsUngrouping  = false

//         callProvider?.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
//             guard let self else { return }
//             if let error {
//                 print("❌ PTT CallKit failed: \(error.localizedDescription)")
//                 // Fallback: play audio without CallKit UI
//                 self.activateAudioSession()
//                 if !groupId.isEmpty {
//                     NativePTTPlayer.shared.startBackgroundReceive(groupId: groupId)
//                     DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                         NativePTTPlayer.shared.sessionDidActivate()
//                     }
//                 }
//             } else {
//                 print("✅ PTT CallKit call reported")
//                 self.activateAudioSession()
//                 if !groupId.isEmpty {
//                     NativePTTPlayer.shared.startBackgroundReceive(groupId: groupId)
//                     DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                         NativePTTPlayer.shared.sessionDidActivate()
//                     }
//                 }
//                 // Auto-end after 60 s to give user time to reply
//                 DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
//                     guard let self, let u = self.activeCallUUID else { return }
//                     self.endCallKitCall(uuid: u)
//                 }
//             }
//         }
//     }

//     private func endCallKitCall(uuid: UUID) {
//         guard activeCallUUID == uuid else { return }    // already ended
//         activeCallUUID = nil
//         let transaction = CXTransaction(action: CXEndCallAction(call: uuid))
//         callController.request(transaction) { error in
//             if let e = error { print("⚠️ PTT CallKit end error: \(e)") }
//             else             { print("✅ PTT CallKit call ended") }
//         }
//     }

//     // ─────────────────────────────────────────────────────
//     // MARK: - Audio session helpers
//     // ─────────────────────────────────────────────────────

//     private func activateAudioSession() {
//         do {
//             let s = AVAudioSession.sharedInstance()
//             // .playback gives loud speaker output without AGC/noise-suppression that
//             // .voiceChat + .playAndRecord applies (which can reduce volume ~60%)
//             try s.setCategory(.playback, mode: .default, options: [.mixWithOthers])
//             try s.setActive(true)
//             try s.overrideOutputAudioPort(.speaker)
//             print("✅ AVAudioSession: PTT receive mode (loud speaker)")
//         } catch {
//             print("⚠️ AVAudioSession activation failed: \(error)")
//         }
//     }

//     private func configureMicSession() {
//         do {
//             let s = AVAudioSession.sharedInstance()
//             try s.setCategory(.playAndRecord, options: [.defaultToSpeaker, .mixWithOthers])
//             try s.setMode(.videoChat)
//             try s.setActive(true)
//             print("✅ AVAudioSession: mic mode")
//         } catch {
//             print("⚠️ AVAudioSession mic mode failed: \(error)")
//         }
//     }

//     private func configureVideoChatSession() {
//         do {
//             let s = AVAudioSession.sharedInstance()
//             try s.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
//             try s.setMode(.videoChat)
//             try s.setActive(true)
//             print("✅ AVAudioSession: videoChat mode")
//         } catch {
//             print("❌ AVAudioSession videoChat mode failed: \(error)")
//         }
//     }

//     private func forceSpeaker() {
//         do {
//             // Lightweight — only overrides output port, does NOT reset category
//             try AVAudioSession.sharedInstance().setActive(true)
//             try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
//             print("🔊 Speaker override applied")
//         } catch {
//             print("❌ Speaker override failed: \(error)")
//         }
//     }

//     // ─────────────────────────────────────────────────────
//     // MARK: - Flutter bridge helpers
//     // ─────────────────────────────────────────────────────

//     private func sendVoIPTokenToFlutter(_ token: String) {
//         guard let controller = window?.rootViewController as? FlutterViewController else { return }
//         let channel = FlutterMethodChannel(name: "ptt/voip",
//                                            binaryMessenger: controller.binaryMessenger)
//         DispatchQueue.main.async {
//             channel.invokeMethod("onVoIPToken", arguments: token)
//         }
//     }

//     private func sendVoIPPushToFlutter(_ payload: [AnyHashable: Any]) {
//         // Normalise to [String: String] and persist so Flutter can read after resume
//         let stringPayload = payload.reduce(into: [String: String]()) { acc, pair in
//             if let k = pair.key as? String { acc[k] = "\(pair.value)" }
//         }
//         UserDefaults.standard.set(stringPayload, forKey: "pending_voip_payload")
//         UserDefaults.standard.synchronize()
//         print("📦 VoIP payload persisted: \(stringPayload)")

//         deliverPayloadToFlutter(stringPayload, retries: 5)
//     }

//     private func deliverPayloadToFlutter(_ payload: [String: String], retries: Int) {
//         guard let controller = window?.rootViewController as? FlutterViewController else {
//             guard retries > 0 else {
//                 print("⚠️ Flutter not ready — payload in UserDefaults for next resume")
//                 return
//             }
//             DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
//                 self?.deliverPayloadToFlutter(payload, retries: retries - 1)
//             }
//             return
//         }
//         let channel = FlutterMethodChannel(name: "ptt/voip",
//                                            binaryMessenger: controller.binaryMessenger)
//         DispatchQueue.main.async {
//             channel.invokeMethod("onVoIPPush", arguments: payload)
//             UserDefaults.standard.removeObject(forKey: "pending_voip_payload")
//             print("✅ VoIP payload delivered to Flutter")
//         }
//     }

//     // ─────────────────────────────────────────────────────
//     // MARK: - APNs registration
//     // ─────────────────────────────────────────────────────

//     override func application(
//         _ application: UIApplication,
//         didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
//     ) {
//         #if DEBUG
//         Auth.auth().setAPNSToken(deviceToken, type: .sandbox)
//         #else
//         Auth.auth().setAPNSToken(deviceToken, type: .prod)
//         #endif
//         Messaging.messaging().apnsToken = deviceToken
//         super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
//     }

//     override func application(
//         _ application: UIApplication,
//         didFailToRegisterForRemoteNotificationsWithError error: Error
//     ) {
//         print("❌ APNs registration failed: \(error.localizedDescription)")
//     }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // MARK: - CXProviderDelegate
// // ─────────────────────────────────────────────────────────────────────────────
// extension AppDelegate: CXProviderDelegate {

//     func providerDidReset(_ provider: CXProvider) {}

//     func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
//         print("📞 User answered PTT call — foregrounding app")
//         invokeFlutterVoIP("onCallAnswered", arguments: nil)
//         action.fulfill()
//     }

//     /// User tapped Decline (or the UI timed out).
//     /// Audio keeps playing — we only dismiss the UI.
//     /// isPTTKilledSessionActive stays true so future pushes skip the call screen.
//     func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
//         print("🛑 PTT call UI dismissed — audio continues silently")
//         activeCallUUID = nil    // prevent double-end from the auto-end timer
//         // Do NOT call disconnect() or reset isPTTKilledSessionActive here.
//         // PTTAudioFinished notification handles that when audio truly ends.
//         invokeFlutterVoIP("onCallEnded", arguments: nil)
//         action.fulfill()
//     }

//     private func invokeFlutterVoIP(_ method: String, arguments: Any?) {
//         guard let controller = window?.rootViewController as? FlutterViewController else { return }
//         let ch = FlutterMethodChannel(name: "ptt/voip", binaryMessenger: controller.binaryMessenger)
//         ch.invokeMethod(method, arguments: arguments)
//     }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // MARK: - PTChannelManagerDelegate & PTChannelRestorationDelegate  (iOS 16+)
// // ─────────────────────────────────────────────────────────────────────────────
// @available(iOS 16.0, *)
// extension AppDelegate: PTChannelManagerDelegate, PTChannelRestorationDelegate {

//     // ── Token ──────────────────────────────────────────────────────────────

//     func channelManager(_ channelManager: PTChannelManager,
//                         receivedEphemeralPushToken pushToken: Data) {
//         let token = pushToken.map { String(format: "%02x", $0) }.joined()
//         print("📲 PTT push token: \(token)")
//         UserDefaults.standard.set(token, forKey: "voip_token")
//         sendVoIPTokenToFlutter(token)
//     }

//     // ── Incoming push ──────────────────────────────────────────────────────

//     func incomingPushResult(channelManager: PTChannelManager,
//                             channelUUID: UUID,
//                             pushPayload: [String: Any]) -> PTPushResult {
//         print("📨 PTT push received — channelUUID: \(channelUUID), payload: \(pushPayload)")

//         let groupId    = pushPayload["groupId"]    as? String ?? ""
//         let senderName = pushPayload["senderName"] as? String ?? "Walkie-Talkie"

//         // Validate UUID matches what we'd derive from groupId
//         let expected = makeChannelUUID(from: groupId)
//         if channelUUID != expected {
//             print("⚠️ channelUUID mismatch — push: \(channelUUID), expected: \(expected)")
//         }

//         NativePTTPlayer.shared.currentGroupId = groupId

//         DispatchQueue.main.async {
//             // Skip NativePTTPlayer if app is already in the foreground (Flutter handles audio)
//             guard UIApplication.shared.applicationState != .active else {
//                 print("🛑 Foreground — skipping NativePTTPlayer to avoid double audio")
//                 return
//             }
//             guard !groupId.isEmpty else { return }

//             NativePTTPlayer.shared.startBackgroundReceive(groupId: groupId)
//             // Fallback: if didActivate fires before the 0.5 s delay, the guard inside
//             // sessionDidActivate prevents double-activation.
//             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                 if !NativePTTPlayer.shared.isAudioSessionActive {
//                     NativePTTPlayer.shared.sessionDidActivate()
//                 }
//             }
//         }

//         sendVoIPPushToFlutter(pushPayload)

//         let participant = PTParticipant(name: senderName, image: nil)
//         return .activeRemoteParticipant(participant)
//     }

//     // ── Session activation ─────────────────────────────────────────────────

//     func channelManager(_ channelManager: PTChannelManager,
//                         didActivate audioSession: AVAudioSession) {
//         print("🎙️ PTT audio session activated by system")
//         NativePTTPlayer.shared.sessionDidActivate(audioSession: audioSession)
//     }

//     func channelManager(_ channelManager: PTChannelManager,
//                         didDeactivate audioSession: AVAudioSession) {
//         print("🎙️ PTT audio session deactivated")
//         // Capture generation NOW (before any async delay) so we can check it later
//         let gen = NativePTTPlayer.shared.currentSessionGeneration
//         // Small delay — iOS sometimes fires didDeactivate while the NEXT push is
//         // already setting up. The generation check inside disconnectIfSessionStillValid
//         // ensures we never kill a new session with a stale deactivation.
//         DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//             NativePTTPlayer.shared.disconnectIfSessionStillValid(generation: gen)
//         }
//     }

//     // ── Channel lifecycle ──────────────────────────────────────────────────

//     func channelDescriptor(restoredChannelUUID channelUUID: UUID) -> PTChannelDescriptor {
//         return PTChannelDescriptor(name: "Walkie-Talkie", image: nil)
//     }

//     func channelManager(_ channelManager: PTChannelManager,
//                         didJoinChannel channelUUID: UUID,
//                         reason: PTChannelJoinReason) {
//         print("🎙️ Joined PTT channel: \(channelUUID)")
//     }

//     func channelManager(_ channelManager: PTChannelManager,
//                         didLeaveChannel channelUUID: UUID,
//                         reason: PTChannelLeaveReason) {
//         print("🎙️ Left PTT channel — rejoining in 2 s")
//         let descriptor = PTChannelDescriptor(name: "Walkie-Talkie", image: nil)
//         DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//             channelManager.requestJoinChannel(channelUUID: channelUUID, descriptor: descriptor)
//         }
//     }

//     func channelManager(_ channelManager: PTChannelManager,
//                         failedToJoinChannel channelUUID: UUID,
//                         error: Error) {
//         print("❌ Failed to join PTT channel: \(error)")
//     }

//     // ── Transmit ───────────────────────────────────────────────────────────

//     func channelManager(_ channelManager: PTChannelManager,
//                         channelUUID: UUID,
//                         didBeginTransmittingFrom source: PTChannelTransmitRequestSource) {
//         print("🎙️ Began transmitting (source: \(source.rawValue))")

//         // Resolve groupId: prefer in-memory, fall back to persisted payload
//         var groupId = NativePTTPlayer.shared.currentGroupId
//         if groupId == nil || groupId!.isEmpty,
//            let stored = UserDefaults.standard.dictionary(forKey: "pending_voip_payload"),
//            let gid = stored["groupId"] as? String {
//             groupId = gid
//             NativePTTPlayer.shared.currentGroupId = gid
//             print("🔄 GroupId recovered from UserDefaults: \(gid)")
//         }

//         guard let gid = groupId, !gid.isEmpty else {
//             print("❌ Cannot transmit — no groupId available")
//             return
//         }
//         NativePTTPlayer.shared.startTransmitting(groupId: gid)
//     }

//     func channelManager(_ channelManager: PTChannelManager,
//                         channelUUID: UUID,
//                         didEndTransmittingFrom source: PTChannelTransmitRequestSource) {
//         print("🎙️ Ended transmitting (source: \(source.rawValue))")
//         NativePTTPlayer.shared.stopTransmitting()
//     }
// }