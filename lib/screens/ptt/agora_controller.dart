import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:get/get.dart';
import 'package:marispeaks/config/app_config.dart';
import 'package:marispeaks/screens/home/CustomBottomSection.dart';

class AgoraController {
  static final AgoraController _instance = AgoraController._internal();
  factory AgoraController() => _instance;
  AgoraController._internal();

  RtcEngine? engine;
  bool isInit = false;
  final _audioPlayer = AudioPlayer();


  Future<void> initialize() async {
    await [Permission.microphone].request();
    await [Permission.speech].request();
    await Future.delayed(const Duration(milliseconds: 300));

    if (isInit) return;

    engine = createAgoraRtcEngine();
    await engine!.initialize(RtcEngineContext(appId: AppConfig.agoraAppID));

    await engine!.setChannelProfile(ChannelProfileType.channelProfileCommunication);
    await engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    // ✅ Voice-optimized audio: 16kHz mono speech codec — matches PTT use case
    await engine!.setAudioProfile(
      profile: AudioProfileType.audioProfileSpeechStandard,
      scenario: AudioScenarioType.audioScenarioChatroom,
    );

    // ✅ AI noise suppression — removes wind, engine noise common on boats
    await engine!.setParameters('{"che.audio.enable_aiaec":true}');
    await engine!.setParameters('{"che.audio.enable_ainr":true}');
    await engine!.setParameters('{"che.audio.ns.mode":2}'); // Aggressive NS

    // ✅ Set session once — music mode, no volume popup
    await _configureAudioSession();

    // ✅ Default to speaker
    await engine!.setDefaultAudioRouteToSpeakerphone(true);

    // ✅ Keep volume indications off (no need)
    // await engine!.enableAudioVolumeIndication(
    //   interval: 0,
    //   smooth: 0,
    //   reportVad: false,
    // );

    // ✅ Event Handlers
    engine!.registerEventHandler(
      RtcEngineEventHandler(
        onError: (err, msg) => debugPrint("Agora Error: $err, $msg"),
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) async {
          debugPrint("✅ Joined channel: ${connection.channelId}");

          await engine?.setEnableSpeakerphone(true);
          await _setAppAudioToMax();

          final myUid = customBottomSection.currentState?.currentUser.userId;
          if (connection.channelId != myUid) await _playBeep();

          debugPrint("🔊 Speakerphone active, full app volume set");
        },
      ),
    );

    isInit = true;

    // ✅ Join your own channel initially
    final myUid = customBottomSection.currentState?.currentUser.userId;
    if (myUid != null) await joinChannel(myUid, 0);

    await toggleMic(false);
    await engine?.enableLocalAudio(false);
  }

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
  }

  Future<void> _setAppAudioToMax() async {
    try {
      await engine?.adjustPlaybackSignalVolume(400); // 0–400 (max)
    } catch (e) {
      debugPrint("⚠️ Unable to set app audio volume: $e");
    }
  }

Future<void> _playBeep() async {
  try {
    await _audioPlayer.setAsset('assets/sounds/pttpress.wav');
    await _audioPlayer.play();
  } catch (e) {
    debugPrint('Error playing beep sound: $e');
  }
}


  Future<void> joinChannel(String channelId, int uid) async {
    if (!isInit || engine == null || channelId.isEmpty) {
      debugPrint("⚠️ Agora not initialized or invalid channel ID.");
      return;
    }

    await engine!.joinChannel(
      token: '',
      channelId: channelId,
      uid: uid,
      options: const ChannelMediaOptions(),
    );
  }

  Future<void> LeaveChannel() async {
    if (engine != null) await engine!.leaveChannel();
  }

  Future<void> toggleMic(bool isMicMuted) async {
    await engine?.muteLocalAudioStream(isMicMuted);
  }

  Future<void> dispose() async {
    debugPrint("PTT Dispose Success");
    await engine?.leaveChannel();
    await engine?.release();
    isInit = false;
  }
}
