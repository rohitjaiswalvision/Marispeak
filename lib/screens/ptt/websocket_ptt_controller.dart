import 'dart:async';
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

  String? senderId;
  String? groupId;
  String? _filePath;
  bool isRecording = false;
  bool isConnected = false;

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

    _player.playerStateStream.listen((state) async {
      if (state.processingState == ProcessingState.completed) {
        await _player.stop(); // fully reset
      }
    });

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

    try {
      _channel = WebSocketChannel.connect(
          Uri.parse("wss://ptt.visionvivante.in")
          // Uri.parse("ws://192.168.3.192:8080"), // ✅ Local Mac server for testing
          );

      _channel!.sink.add(jsonEncode({
        "type": "register",
        "userId": senderId,
      }));
      // (catch block removed here)

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
      // Check network connectivity
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) return;

      // Make sure the WebSocket is not null and still open
      if (_channel != null) {
        try {
          _channel!.sink.add(jsonEncode({"type": "ping"}));
        } catch (e) {
          // The channel might be closed or in error state
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

      playReceived(path);
    }
  }

  // ------------------------------------------------------------
  // PLAYBACK (Latest always wins)
  // ------------------------------------------------------------
  Future<void> playReceived(String path) async {
    try {
      // final session = await AudioSession.instance;

      // await session.configure(
      //   const AudioSessionConfiguration.music(),
      // );
      // await session.setActive(true);

      if (Platform.isIOS) forceSpeakerOnIOS();

      // // 🛑 Ensure previous audio is fully stopped before new one loads
      // if (_player.playing) {
      //   await _player.stop();
      // }

      // 🧹 Reset + load new audio
      await _player.setAudioSource(
        AudioSource.uri(Uri.file(path)),
      );

      await _player.play();
      print("playing audio");
    } catch (e, stack) {
      print("❌ not playing audio: $e");
      print(stack);
    }
  }

  // ------------------------------------------------------------
  // RECORDING
  // ------------------------------------------------------------
  Future<void> startRecording() async {
    if (isRecording) return;
    await customBottomSection.currentState?.playBeep();
    if (!await _recorder.hasPermission()) {
      await Permission.microphone.request();
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    _filePath = "${dir.path}/tx_${DateTime.now().millisecondsSinceEpoch}.aac";

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
        numChannels: 1,
      ),
      path: _filePath!,
    );

    isRecording = true;
  }

  Future<void> stopRecording() async {
    if (!isRecording) return;
    await _recorder.stop();
    isRecording = false;
  }

  Future<void> sendAudio() async {
    if (_filePath == null || groupId == null || !isConnected) return;

    final file = File(_filePath!);
    if (!await file.exists()) return;

    final msg = jsonEncode({
      "type": "audio",
      "groupId": groupId,
      "sender": senderId,
      "chunk": base64Encode(await file.readAsBytes()),
    });

    _channel?.sink.add(msg);
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
    // Reset the flag after 10 seconds (enough time to receive and play audio)
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
