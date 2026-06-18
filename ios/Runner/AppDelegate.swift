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
        let serverUrl = storedUrl ?? "ws://192.168.3.192:3010" // Default to dev, not prod
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
    func sessionDidActivate() {
        isAudioSessionActive = true
        
        // 🔊 Force the audio to play from the main loud speaker at FULL volume!
        let session = AVAudioSession.sharedInstance()
        do {
            // ✅ FIX: Use .playAndRecord to support both capturing mic (when user holds native PTT button)
            // and playing loud audio (defaultToSpeaker).
            try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth])
            // ✅ FIX: Must call setActive(true) BEFORE overrideOutputAudioPort, otherwise the
            // override can silently fail on some devices and fall back to the quiet earpiece.
            try session.setActive(true)
            try session.overrideOutputAudioPort(.speaker) // 🔊 CRITICAL for loud volume
            print("🔊 NativePTTPlayer: Audio session active — full-volume speaker output (playAndRecord)")
        } catch {
            print("❌ NativePTTPlayer: Failed to configure speaker - \(error)")
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
            let serverUrl = storedUrl ?? "ws://192.168.3.192:3010" // Default to dev, not prod
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

  // 🔑 Tracks if the app has ever been in the foreground during this process lifetime.
  // false = app was just woken from killed state by a VoIP/PTT push
  // true  = app was backgrounded by user (Home button) — PTT works silently
  var hasBeenInForeground = false

  // 📻 Once user accepts/declines the first CallKit screen, this stays TRUE
  // so all subsequent PTT pushes in the same session skip the CallKit UI
  // and just play audio silently. Resets when the full audio session ends.
  var isPTTKilledSessionActive = false

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
      try session.setActive(true)
      try session.overrideOutputAudioPort(.speaker)
      print("🔊 Speaker output overridden (lightweight, session category preserved)")
    } catch {
      print("❌ Failed to override speaker port: \(error)")
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
    }
    
    func incomingPushResult(channelManager: PTChannelManager, channelUUID: UUID, pushPayload: [String : Any]) -> PTPushResult {
        print("📨 PTT Push Received: \(pushPayload)")

        let groupId = pushPayload["groupId"] as? String ?? ""
        let senderName = pushPayload["senderName"] as? String ?? "Walkie-Talkie"
        let senderId = pushPayload["senderId"] as? String ?? ""
        
        // ✅ Decide the correct group to reply to:
        // If groupId == our own ID, it's a 1-on-1 message, so we must reply to the senderId.
        // Otherwise, it's a group chat, so we reply to the same groupId.
        let myUserId = UserDefaults.standard.string(forKey: "flutter.ptt_user_id") ?? ""
        let replyGroupId = (groupId == myUserId && !senderId.isEmpty) ? senderId : groupId
        NativePTTPlayer.shared.currentGroupId = replyGroupId // ✅ Cache for replying

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
                        NativePTTPlayer.shared.sessionDidActivate()
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
        print("🎙️ Left PTT Channel. Rejoining silently to stay ready for next push in 2 seconds...")
        let descriptor = PTChannelDescriptor(name: "Walkie-Talkie", image: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            channelManager.requestJoinChannel(channelUUID: channelUUID, descriptor: descriptor)
        }
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
