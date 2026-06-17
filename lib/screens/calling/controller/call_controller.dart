import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:get/get.dart';
import 'package:marispeaks/config/app_config.dart';
import 'package:marispeaks/models/call.dart';
import 'package:marispeaks/routes/app_routes.dart';
import 'package:marispeaks/screens/home/CustomBottomSection.dart';
import 'package:marispeaks/screens/home/MainScreenUI.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';

class CallController extends GetxController {
  final Call call;
  CallController({required this.call});

  late RtcEngine engine;

  Timer? _callTimer;
  final RxInt seconds = 0.obs;
  final RxnInt remoteUid = RxnInt();
  AudioPlayer? _audioPlayer;
  final RxBool isLocalUserJoined = false.obs;
  final RxBool speaker = true.obs;
  final RxBool mute = false.obs;
  final RxBool switchCamera = false.obs;
  static final RxBool isCallActive = false.obs;
  static final RxBool showFloatingBtn = false.obs;
  bool _isRingtonePlaying = false;
  String? callstatus;

  @override
  void onInit() {
    super.onInit();
    _initAgoraCall();
    mainScreenKey.currentState?.notifyCallStatusChange(
  active: true,
  showBtn: false,
);
  }

  @override
  void onClose() async {
    await _cleanup();
    mainScreenKey.currentState?.notifyCallStatusChange(
  active: false,
  showBtn: false,
);

    super.onClose();
  }

    void minimizeCallScreen() {
      mainScreenKey.currentState?.notifyCallStatusChange(
  active: true,
  showBtn: true,
);

    if (Get.context != null) {
      Navigator.pop(Get.context!);
    } else {
      Get.back();
    }
  }

   void restoreCallScreen() {
    if (call.isVideo) {
      Get.toNamed(AppRoutes.videoCall, arguments: {'call': call});
    } else {
      Get.toNamed(AppRoutes.voiceCall, arguments: {'call': call});
    }
    showFloatingBtn.value = false;
  }

  Future<void> _initAgoraCall() async {
    // customBottomSection.currentState?.AgoraDispose();
    await Future.delayed(const Duration(milliseconds: 500));

    await [Permission.microphone, if (call.isVideo) Permission.camera].request();
    await Future.delayed(const Duration(milliseconds: 300));

    await _playRingtone();

    engine = createAgoraRtcEngine();
    await engine.initialize(
      const RtcEngineContext(
        appId: AppConfig.agoraAppID,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("✅ Joined channel: ${connection.channelId}, localUid: ${connection.localUid}");
          isLocalUserJoined.value = true;
          callstatus = "Reject";
        },
        onUserJoined: (RtcConnection connection, int uid, int elapsed) async {
          debugPrint("👤 Remote user joined: $uid");
          remoteUid.value = uid;
          _startCallTimer();
           callstatus = "Answered";
        },
        onUserOffline: (RtcConnection connection, int uid, UserOfflineReasonType reason) async {
          debugPrint("🚪 Remote user left: $uid, reason: ${reason.name}");
          await _endCallAfterRemoteLeft();
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          debugPrint("📴 Left channel: ${connection.channelId}");
        },
        onError: (err, msg) {
          debugPrint("❗ Agora Error: $err - $msg");
        },
      ),
    );

    await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    if (call.isVideo) {
      await engine.enableVideo();
      await engine.startPreview();
    } else {
      await engine.enableAudio();
    }


    //await engine.setEnableSpeakerphone(true);

    await engine.joinChannel(
      token: '', // TODO: Replace with secure token logic if required
      channelId: call.callerId,
      uid: 0,
      options: const ChannelMediaOptions(),
    );

    //_startTimeoutFallback();
  }

  void onToggleSpeaker() {
    speaker.toggle();
    engine.setEnableSpeakerphone(speaker.value);
  }

  void onToggleMute() {
    mute.toggle();
    engine.muteLocalAudioStream(mute.value);
  }

  void onSwitchCamera() {
    switchCamera.toggle();
    engine.switchCamera();
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      seconds.value++;
    });
    Future.microtask(() => stopRingtone());
  }

  Future<void> _startTimeoutFallback() async {
    await Future.delayed(const Duration(seconds: 1));
    if (remoteUid.value == null) {
      debugPrint("⏱️ Timeout: remote user did not join");
      await onEndCall();
    }
  }

  Future<void> onEndCall() async {
     await _endCallAfterRemoteLeft();
  //  Get.back(result: remoteUid.value);
  }

  Future<void> _endCallAfterRemoteLeft() async {
    remoteUid.value = null;
    seconds.value = 0;
    _callTimer?.cancel();
    await _cleanup();
    if (Get.context != null) {
      Navigator.pop(Get.context!, callstatus);
    } else {
      Get.back(result: callstatus);
    }
  }

  Future<void> _cleanup() async {
    _callTimer?.cancel();
    Future.microtask(() => stopRingtone());

    try {
      await engine.leaveChannel();
    } catch (_) {}
    try {
      await engine.release();
    } catch (_) {}
  }

  Future<void> _playRingtone() async {
    if (call.isCaller) {
      _isRingtonePlaying = true;
       _audioPlayer = AudioPlayer();
  await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
  await _audioPlayer!.play(AssetSource('sounds/phone-calling.mp3'),
      volume: 1.0);
    }
  }


void stopRingtone() {
  _audioPlayer?.stop();
  _isRingtonePlaying = false;
  print("ringing stopped");
}




Future<void> onRemoteRejected() async {
  debugPrint("🚫 Remote user rejected the call via FCM");

     Future.microtask(() => stopRingtone());
  await _cleanup();
  
  if (Get.context != null) {
    Navigator.pop(Get.context!, 'rejected');
  } else {
    Get.back(result: 'rejected');
  }
  
}

}

