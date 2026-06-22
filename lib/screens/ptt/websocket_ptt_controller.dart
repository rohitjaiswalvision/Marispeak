import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marispeaks/config/environment.dart';
import 'package:marispeaks/screens/home/CustomBottomSection.dart';
import 'package:marispeaks/services/voip_service.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WebSocketPTTController with WidgetsBindingObserver {
  static final WebSocketPTTController _instance =
      WebSocketPTTController._internal();
  factory WebSocketPTTController() => _instance;
  WebSocketPTTController._internal();

  static const platform = MethodChannel('custom.audio');

  WebSocketChannel? _channel;
  StreamSubscription? _wsSubscription;
  Timer? _pingTimer;
  Timer? _netRetryTimer;

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  // ✅ Playback queue — prevents audio chunks from overlapping
  final Queue<String> _playQueue = Queue<String>();
  bool _isPlaying = false;

  // ✅ Real-time chunking — sends audio every 1.5s while button is held
  Timer? _chunkTimer;

  String? senderId;
  String? groupId;
  String? _activeChatGroupId;
  String? _filePath;
  bool isRecording = false;
  bool isConnected = false;

  static const _activeGroupKey = 'ptt_active_group_id';

  /// Stable channel id for 1-to-1 PTT (both users must use the same value).
  static String sharedChannelId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return ids.join('_');
  }

  static const RecordConfig _voiceConfig = RecordConfig(
    encoder: AudioEncoder.aacLc,
    sampleRate: 16000, // ✅ Optimized for voice (16kHz is standard for PTT/VoIP)
    bitRate:
        32000, // ✅ Optimized for voice (32kbps provides clear voice with small files)
    numChannels: 1,
    echoCancel: true, // ✅ Reduce echo/feedback
    noiseSuppress: true, // ✅ Remove background noise for clearer voice
    autoGain: true, // ✅ Normalize volume levels
  );

  // ------------------------------------------------------------
  // INITIALIZE
  // ------------------------------------------------------------
  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);

    await Permission.microphone.request();

    final session = await AudioSession.instance;
    // ✅ FIX: Do NOT use AudioSessionConfiguration.speech() — it sets .voiceChat mode
    // which enables AGC + noise suppression and routes output to the EARPIECE on iPhone 12 Pro.
    // Use .playAndRecord with .defaultToSpeaker so audio always comes from the loud speaker.
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      // ✅ Use | operator to combine bitmask options (NOT named constructor params)
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.defaultToSpeaker |
              AVAudioSessionCategoryOptions.mixWithOthers |
              AVAudioSessionCategoryOptions.allowBluetooth,
      avAudioSessionMode:
          AVAudioSessionMode.defaultMode, // ✅ correct enum value
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions:
          AVAudioSessionSetActiveOptions.none, // ✅ use .none constant
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false,
    ));
    // ✅ FIX: Removed await session.setActive(true) here to prevent Bluetooth hijacking.
    // We only activate the session when actively transmitting or receiving.

    if (Platform.isIOS) forceSpeakerOnIOS();

    // ✅ FIX: When iOS issues a refreshed PTT token, send it to the server
    // immediately so the server always has the latest token for push delivery.
    VoIPService().onVoIPTokenRefreshed = (newToken) {
      debugPrint('📲 Token refreshed — sending to server immediately');
      _sendVoIPTokenToServer();
    };

    startNetworkMonitor();

    debugPrint("🎧 PTT Controller Ready");
  }

  Future<void> forceSpeakerOnIOS() async {
    try {
      await platform.invokeMethod("forceSpeaker");
    } catch (_) {}
  }

  // ------------------------------------------------------------
  // NETWORK WATCHER
  // ------------------------------------------------------------
  void startNetworkMonitor() {
    Connectivity().onConnectivityChanged.listen((status) {
      if (status != ConnectivityResult.none) {
        debugPrint("🌐 Network back");
        if (!isConnected && senderId != null) connect(senderId!);
      } else {
        debugPrint("⚠ No network, retrying...");
        _startRetry();
      }
    });
  }

  void _startRetry() {
    _netRetryTimer?.cancel();
    _netRetryTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final result = await Connectivity().checkConnectivity();
      if (result != ConnectivityResult.none) {
        _netRetryTimer?.cancel();
        if (!isConnected && senderId != null) connect(senderId!);
      }
    });
  }

  // ------------------------------------------------------------
  // CONNECT
  // ------------------------------------------------------------
  Future<void> connect(String uid) async {
    if (isConnected) return;

    senderId = uid.trim();

    // ✅ Persist userId to UserDefaults (via SharedPreferences) so native Swift
    // can read it when the app is locked and connect WebSocket natively
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ptt_user_id', senderId!);
      _activeChatGroupId ??= prefs.getString(_activeGroupKey);
    } catch (_) {}

    // Re-join the active chat channel after reconnect — not our own userId
    groupId = (_activeChatGroupId != null && _activeChatGroupId!.isNotEmpty)
        ? _activeChatGroupId!
        : senderId;

    try {
      // ✅ Use environment-based server URL
      final serverUrl = Environment.current.pttServerUrl;

      if (Environment.current.enableLogging) {
        debugPrint("🔌 Connecting to PTT server: $serverUrl");
      }

      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));

      _channel!.sink.add(jsonEncode({
        "type": "register",
        "userId": senderId,
      }));

      // ✅ Send our VoIP push token to the server so it can wake us when offline
      if (Platform.isIOS) {
        _sendVoIPTokenToServer();
        // ✅ FIX: Retry after 2s in case the PTT framework delivers the token
        // AFTER the WebSocket connects (common on first launch)
        Future.delayed(const Duration(seconds: 2), () {
          if (isConnected) _sendVoIPTokenToServer();
        });
      }

      _wsSubscription = _channel!.stream.listen(
        (event) => _onWSMessage(event),
        onError: (_) => _onDisconnect(),
        onDone: () => _onDisconnect(),
        cancelOnError: true,
      );

      isConnected = true;
      _startPing();

      debugPrint("✅ Connected as $senderId");

      joinGroup(groupId!);
    } catch (e) {
      debugPrint("❌ Failed connect: $e");
      _onDisconnect();
    }
  }

  /// Sends VoIP token to server if we have one and are connected.
  void _sendVoIPTokenToServer() {
    final voipToken = VoIPService().voipToken;
    if (voipToken != null && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode({
          "type": "voip_token",
          "token": voipToken,
        }));
        debugPrint("📲 Sent VoIP token to server");
      } catch (_) {}
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) return;

      if (_channel != null) {
        try {
          _channel!.sink.add(jsonEncode({"type": "ping"}));
        } catch (e) {
          print("Ping failed: $e");
        }
      }
    });
  }

  // ------------------------------------------------------------
  // RECEIVE MESSAGES
  // ------------------------------------------------------------
  Future<void> _onWSMessage(dynamic event) async {
    final data = jsonDecode(event);

    if (data["type"] == "audio") {
      if (data["sender"] == senderId) {
        debugPrint("🔇 Ignoring our own audio chunk");
        return;
      }

      final bytes = base64Decode(data["chunk"]);
      debugPrint("📦 Flutter received ${bytes.length} bytes of audio");

      final dir = await getApplicationDocumentsDirectory();
      // ✅ FIX: Use UUID + timestamp to ensure unique filenames
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random =
          (bytes.hashCode & 0xFFFF).toRadixString(16).padLeft(4, '0');
      final path = "${dir.path}/rx_${timestamp}_$random.m4a";
      final file = File(path);

      // ✅ Write file with flush
      await file.writeAsBytes(bytes, flush: true);

      // ✅ Queue immediately - verification happens in playback
      _enqueuePlayback(path);
    }
  }

  // ------------------------------------------------------------
  // PLAYBACK QUEUE — gapless, no overlapping
  // ------------------------------------------------------------
  void _enqueuePlayback(String path) {
    _playQueue.add(path);
    if (!_isPlaying) _processPlayQueue();
  }

  Future<void> _processPlayQueue() async {
    if (_playQueue.isEmpty) {
      if (_isPlaying) {
        _isPlaying = false;
        // ✅ FIX: Deactivate session when playback queue is completely empty
        final session = await AudioSession.instance;
        try {
          await session.setActive(false);
        } catch (_) {}
      }
      return;
    }

    if (!_isPlaying) {
      _isPlaying = true;
      // ✅ FIX: Activate session when a new message starts playing so you can hear it
      final session = await AudioSession.instance;
      await session.setActive(true);
    }

    final path = _playQueue.removeFirst();

    try {
      // ✅ FIX: Verify file exists and has content before trying to play
      final file = File(path);
      if (!await file.exists()) {
        debugPrint("⚠️ Audio file not found, skipping: $path");
        _processPlayQueue(); // Skip to next
        return;
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        debugPrint("⚠️ Audio file is empty, skipping: $path");
        await file.delete();
        _processPlayQueue(); // Skip to next
        return;
      }

      // ✅ FIX: Re-assert speaker output before every chunk on iOS.
      if (Platform.isIOS) {
        try {
          await platform.invokeMethod("forceSpeaker");
        } catch (_) {}
      }

      debugPrint("🔊 Flutter playing audio chunk: $path (${fileSize} bytes)");
      await _player.setVolume(1.0); // ✅ Always play at max volume
      await _player.setAudioSource(AudioSource.uri(Uri.file(path)));
      await _player.play();

      // Wait until this chunk finishes before playing the next
      await _player.playerStateStream.firstWhere(
        (s) =>
            s.processingState == ProcessingState.completed ||
            s.processingState == ProcessingState.idle,
      );
      debugPrint("✅ Flutter finished playing audio chunk");
    } catch (e, stack) {
      debugPrint("❌ Playback error: $e - Skipping to next chunk");
      debugPrint(stack.toString());
      // ✅ FIX: Don't let one bad chunk stop the entire queue - skip to next
    } finally {
      // ✅ Always clean up temp files to avoid storage bloat
      try {
        await File(path).delete();
      } catch (_) {}
    }

    // Play next chunk (recursive call)
    _processPlayQueue();
  }

  // ------------------------------------------------------------
  // RECORDING — with real-time chunked streaming
  // ------------------------------------------------------------
  Future<void> startRecording() async {
    if (isRecording) {
      debugPrint("⚠️ Already recording, ignoring startRecording() call");
      return;
    }

    // ✅ FIX: Clean up any leftover state from previous recording
    _chunkTimer?.cancel();
    _chunkTimer = null;
    _filePath = null;

    // ✅ FIX: Ensure recorder is fully stopped before starting new recording
    final isCurrentlyRecording = await _recorder.isRecording();
    if (isCurrentlyRecording) {
      debugPrint(
          "⚠️ Recorder still active from previous session, stopping it first...");
      try {
        await _recorder.stop();
      } catch (e) {
        debugPrint("⚠️ Error stopping previous recording: $e");
      }
      // Wait for recorder to fully release resources
      await Future.delayed(const Duration(milliseconds: 200));
    }

    isRecording = true;
    debugPrint("🎙️ Starting recording with real-time chunking...");

    await customBottomSection.currentState?.playBeep();
    if (!await _recorder.hasPermission()) {
      await Permission.microphone.request();
      isRecording = false;
      return;
    }

    await _startNewChunk();

    // ✅ FIX: Activate audio session only when PTT button is held
    final session = await AudioSession.instance;
    await session.setActive(true);

    // ✅ Send audio chunks every 1.0s while button is held
    // This means recipients hear you WHILE you're still talking
    debugPrint("⏱️ Starting chunk timer - will send audio every 1.0s");
    _chunkTimer =
        Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      if (!isRecording) {
        timer.cancel(); // ✅ FIX: Safely cancel this specific timer instance
        debugPrint("⏹️ Recording stopped, canceling chunk timer");
        return;
      }
      debugPrint("⏰ Chunk timer fired - sending current chunk...");
      await _flushAndContinue();
    });
  }

  /// Start recording into a new temp file
  Future<void> _startNewChunk() async {
    final dir = await getApplicationDocumentsDirectory();
    _filePath = "${dir.path}/tx_${DateTime.now().millisecondsSinceEpoch}.m4a";
    debugPrint("🎬 Starting new chunk: $_filePath");
    await _recorder.start(_voiceConfig, path: _filePath!);
    debugPrint("✅ Recorder started successfully");
  }

  /// Stop current chunk, send it, start a new chunk (called while button held)
  Future<void> _flushAndContinue() async {
    if (!isRecording) return;

    // ✅ FIX: Check if recorder is actually recording before trying to stop
    final isCurrentlyRecording = await _recorder.isRecording();
    if (!isCurrentlyRecording) {
      debugPrint("⚠️ Recorder not active, skipping flush");
      return;
    }

    final currentPath = _filePath;
    debugPrint("📤 Flushing chunk: $currentPath");

    await _recorder.stop();

    // ✅ Send the chunk immediately so receiver hears in real-time
    if (currentPath != null) {
      await _sendFile(currentPath);
      debugPrint("✅ Chunk sent successfully");
    }

    // ✅ Only start new chunk if still recording
    if (isRecording) {
      await _startNewChunk();
    }
  }

  Future<void> stopRecording() async {
    if (!isRecording) return;

    debugPrint("🛑 Stopping recording...");

    // ✅ FIX: Cancel timer first to prevent it from interfering
    _chunkTimer?.cancel();
    _chunkTimer = null;

    // ✅ FIX: Stop the recorder and get the final chunk path BEFORE marking as not recording
    final finalPath = _filePath;

    // ✅ Check if recorder is actually recording before trying to stop
    final isCurrentlyRecording = await _recorder.isRecording();
    if (isCurrentlyRecording) {
      await _recorder.stop();
    }

    // ✅ Mark as not recording BEFORE sending final chunk
    isRecording = false;

    // ✅ Send the final chunk immediately
    if (finalPath != null) {
      debugPrint("📤 Sending final chunk: $finalPath");
      await _sendFile(finalPath);
    }

    // ✅ FIX: Wait briefly for the native audio engine to fully stop releasing resources
    // before deactivating the session. This prevents the iOS -12988 'Busy' crash!
    await Future.delayed(const Duration(milliseconds: 300));
    final session = await AudioSession.instance;
    try {
      await session.setActive(false);
    } catch (e) {
      debugPrint("⚠️ Session deactivation failed slightly, retrying... $e");
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        await session.setActive(false);
      } catch (_) {}
    }

    debugPrint("✅ Recording stopped and final chunk sent");
  }

  Future<void> sendAudio() async {
    // ✅ DEPRECATED: The final chunk is now sent automatically in stopRecording()
    // This method is kept for backwards compatibility but does nothing
    debugPrint(
        "📋 sendAudio() called - final chunk already sent in stopRecording()");
    return;
  }

  Future<void> _sendFile(String path) async {
    if (groupId == null) return;

    // ✅ FIX: Wait up to 3 seconds for WebSocket to connect before dropping the chunk.
    // This fixes the "first message doesn't send" bug if the user presses the button
    // immediately after opening the app before the socket finishes connecting.
    if (!isConnected || _channel == null) {
      debugPrint("⏳ Waiting for WebSocket to connect before sending audio...");
      for (int i = 0; i < 15; i++) {
        if (isConnected && _channel != null) break;
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    if (!isConnected || _channel == null) {
      debugPrint("❌ Still not connected, dropping chunk.");
      return;
    }

    final file = File(path);
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return;

    // Generate MD5 channelUUID
    final md5Bytes = md5.convert(utf8.encode(groupId ?? ""));
    final hex = md5Bytes.toString().toUpperCase();
    final channelUUID =
        "${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}";
    debugPrint("📤 Sending audio with channelUUID: $channelUUID");

    final msg = jsonEncode({
      "type": "audio",
      "groupId": groupId,
      "channelUUID": channelUUID,
      "sender": senderId,
      "chunk": base64Encode(bytes),
    });

    try {
      _channel?.sink.add(msg);
    } catch (e) {
      debugPrint("❌ Failed to send chunk: $e");
    }

    // ✅ Clean up sent file immediately
    try {
      await file.delete();
    } catch (_) {}
  }

  // ------------------------------------------------------------
  // GROUPS
  // ------------------------------------------------------------
  void joinGroup(String newGroupId) {
    final id = newGroupId.trim();
    if (id.isEmpty) return;

    groupId = id;
    _activeChatGroupId = id;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_activeGroupKey, id);
    }).catchError((_) {});

    if (isConnected && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode({
          "type": "switch",
          "newGroupId": groupId,
        }));
      } catch (e) {
        debugPrint("❌ Failed to join group (socket closed): $e");
      }
    }

    // ✅ Tell iOS PushToTalk framework to join the correct Channel UUID
    if (Platform.isIOS) {
      const pttVoipChannel = MethodChannel("ptt/voip");
      pttVoipChannel
          .invokeMethod("joinChannel", {"groupId": groupId}).catchError((_) {});
    }

    debugPrint("👥 Joined group $groupId");
  }

  // ------------------------------------------------------------
  // DISCONNECT
  // ------------------------------------------------------------
  Future<void> _onDisconnect() async {
    isConnected = false;

    try {
      await _wsSubscription?.cancel();
    } catch (_) {}
    try {
      await _channel?.sink.close();
    } catch (_) {}

    _wsSubscription = null;
    _channel = null;
    _pingTimer?.cancel();

    debugPrint("🔌 Disconnected");

    Future.delayed(const Duration(seconds: 2), () {
      if (!isConnected && senderId != null) connect(senderId!);
    });
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    _pingTimer?.cancel();
    _netRetryTimer?.cancel();
    _chunkTimer?.cancel();
    await _player.dispose();
    await _recorder.dispose();
    await _wsSubscription?.cancel();
    await _channel?.sink.close();

    debugPrint("🧹 Controller disposed");
  }

  // ------------------------------------------------------------
  // LIFECYCLE
  // ------------------------------------------------------------
  bool _isHandlingPush = false;

  void handlePushConnect(String groupId, String userId) async {
    if (Platform.isIOS) {
      bool inBackground = await VoIPService().isAppInBackground();
      if (inBackground) {
        debugPrint(
            "🟡 Ignoring VoIP push in Flutter because iOS app is in background. Swift handles it!");
        return;
      }
    }

    _isHandlingPush = true;
    connect(userId);
    joinGroup(groupId);
    Future.delayed(const Duration(seconds: 10), () {
      _isHandlingPush = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      if (isRecording) {
        debugPrint(
            "🛑 App backgrounded while recording! Stopping record timer.");
        await stopRecording();
      }

      if (_isHandlingPush) {
        debugPrint(
            "🟡 App backgrounded, but ignoring WebSocket close because handling PTT push");
        return;
      }
      debugPrint("🔴 App backgrounded, closing WebSocket to force VoIP Push");
      _wsSubscription?.cancel();
      _channel?.sink.close();
      _channel = null;
      isConnected = false;
    }

    if (state == AppLifecycleState.resumed) {
      if (Platform.isIOS) {
        // ✅ Check if we are actually in the background (woken by VoIP Push)
        // If we are, DO NOT connect Flutter's WebSocket! Let Swift handle the audio natively!
        bool inBackground = await VoIPService().isAppInBackground();
        if (inBackground) {
          debugPrint(
              "🟡 App 'resumed' by iOS in background (PushKit) — NOT connecting Flutter WebSocket");
          return;
        }
      }

      debugPrint("🟢 App resumed, reconnecting WebSocket");
      if (senderId != null) {
        await connect(senderId!);
        // connect() re-joins _activeChatGroupId; call again if chat opened while suspended
        if (_activeChatGroupId != null && _activeChatGroupId!.isNotEmpty) {
          joinGroup(_activeChatGroupId!);
        }
      }
    }
  }
}
