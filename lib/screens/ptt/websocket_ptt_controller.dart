import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:just_audio/just_audio.dart';
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
  String? _filePath;
  bool isRecording = false;
  bool isConnected = false;

  // ✅ Voice-optimized codec config — 4× smaller than previous 44100/128kbps
  static const RecordConfig _voiceConfig = RecordConfig(
    encoder: AudioEncoder.aacLc,
    sampleRate: 16000, // was 44100 — voice-only needs 16kHz
    bitRate: 32000,    // was 128000 — 32kbps is plenty for voice
    numChannels: 1,
  );

  // ------------------------------------------------------------
  // INITIALIZE
  // ------------------------------------------------------------
  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);

    await Permission.microphone.request();

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    await session.setActive(true);

    if (Platform.isIOS) forceSpeakerOnIOS();

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
    groupId = uid.trim();

    // ✅ Persist userId to UserDefaults (via SharedPreferences) so native Swift
    // can read it when the app is locked and connect WebSocket natively
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ptt_user_id', senderId!);
    } catch (_) {}

    try {
      _channel = WebSocketChannel.connect(
          Uri.parse("ws://192.168.3.192:3010") // 🔧 LOCAL TESTING
          );

      _channel!.sink.add(jsonEncode({
        "type": "register",
        "userId": senderId,
      }));

      // ✅ Send our VoIP push token to the server so it can wake us when offline
      if (Platform.isIOS) {
        final voipToken = VoIPService().voipToken;
        if (voipToken != null) {
          _channel!.sink.add(jsonEncode({
            "type": "voip_token",
            "token": voipToken,
          }));
          debugPrint("📲 Sent VoIP token to server");
        }
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
      final bytes = base64Decode(data["chunk"]);
      final dir = await getApplicationDocumentsDirectory();
      final path =
          "${dir.path}/rx_${DateTime.now().millisecondsSinceEpoch}.aac";
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      // ✅ Queue chunk instead of playing immediately (prevents overlapping audio)
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
      _isPlaying = false;
      return;
    }
    _isPlaying = true;
    final path = _playQueue.removeFirst();

    try {
      if (Platform.isIOS) forceSpeakerOnIOS();

      await _player.setAudioSource(AudioSource.uri(Uri.file(path)));
      await _player.play();

      // Wait until this chunk finishes before playing the next
      await _player.playerStateStream.firstWhere(
        (s) => s.processingState == ProcessingState.completed ||
               s.processingState == ProcessingState.idle,
      );
    } catch (e, stack) {
      debugPrint("❌ Playback error: $e");
      debugPrint(stack.toString());
    } finally {
      // ✅ Always clean up temp files to avoid storage bloat
      try { await File(path).delete(); } catch (_) {}
    }

    // Play next chunk
    _processPlayQueue();
  }

  // ------------------------------------------------------------
  // RECORDING — with real-time chunked streaming
  // ------------------------------------------------------------
  Future<void> startRecording() async {
    if (isRecording) return;
    await customBottomSection.currentState?.playBeep();
    if (!await _recorder.hasPermission()) {
      await Permission.microphone.request();
      return;
    }

    await _startNewChunk();
    isRecording = true;

    // ✅ Send audio chunks every 1.5s while button is held
    // This means recipients hear you WHILE you're still talking
    _chunkTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (!isRecording) {
        _chunkTimer?.cancel();
        return;
      }
      await _flushAndContinue();
    });
  }

  /// Start recording into a new temp file
  Future<void> _startNewChunk() async {
    final dir = await getApplicationDocumentsDirectory();
    _filePath = "${dir.path}/tx_${DateTime.now().millisecondsSinceEpoch}.aac";
    await _recorder.start(_voiceConfig, path: _filePath!);
  }

  /// Stop current chunk, send it, start a new chunk (called while button held)
  Future<void> _flushAndContinue() async {
    if (!isRecording) return;
    final currentPath = _filePath;
    await _recorder.stop();
    if (currentPath != null) await _sendFile(currentPath);
    await _startNewChunk(); // immediately start recording next chunk
  }

  Future<void> stopRecording() async {
    if (!isRecording) return;
    _chunkTimer?.cancel();
    _chunkTimer = null;
    await _recorder.stop();
    isRecording = false;
  }

  Future<void> sendAudio() async {
    // ✅ Send the final chunk after button is released
    if (_filePath == null || groupId == null || !isConnected) return;
    await _sendFile(_filePath!);
  }

  Future<void> _sendFile(String path) async {
    if (groupId == null || !isConnected) return;
    final file = File(path);
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return;

    final msg = jsonEncode({
      "type": "audio",
      "groupId": groupId,
      "sender": senderId,
      "chunk": base64Encode(bytes),
    });

    try {
      _channel?.sink.add(msg);
    } catch (e) {
      debugPrint("❌ Failed to send chunk: $e");
    }

    // ✅ Clean up sent file immediately
    try { await file.delete(); } catch (_) {}
  }

  // ------------------------------------------------------------
  // GROUPS
  // ------------------------------------------------------------
  void joinGroup(String id) {
    groupId = id.trim();
    _channel?.sink.add(jsonEncode({
      "type": "switch",
      "newGroupId": groupId,
    }));
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

  void handlePushConnect(String id) {
    _isHandlingPush = true;
    connect(id);
    joinGroup(id);
    Future.delayed(const Duration(seconds: 10), () {
      _isHandlingPush = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
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
      debugPrint("🟢 App resumed, reconnecting WebSocket");
      if (senderId != null) {
        connect(senderId!);
      }
    }
  }
}
