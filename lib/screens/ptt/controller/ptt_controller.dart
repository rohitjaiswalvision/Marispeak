// import 'package:agora_rtc_engine/agora_rtc_engine.dart';
// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:get/get.dart';

// class PTTController extends GetxController {
//   final RxBool isEngineReady = false.obs;
//   late final RtcEngine _engine;
//   final String appId = "3d0ef15dd9fe49128d581380eeaea151"; // Replace with your Agora App ID
//   final RxBool isJoined = false.obs;
//   final RxBool isMicOn = false.obs;
//   String receiverId = "1";
//   late int _localUid;
//   late String _currentChannel;

//   // Initialize Agora only once
//   Future<void> initAgora(String channelName, int uid) async {
//     if (isEngineReady.value) return;

//     _localUid = uid;
//     _currentChannel = channelName;

//     print("🎙️ Initializing Agora Engine...");
//     await [Permission.microphone].request();

//     _engine = createAgoraRtcEngine();
//     await _engine.initialize(RtcEngineContext(appId: appId));
//     print("✅ Agora engine initialized");

//     _engine.registerEventHandler(
//       RtcEngineEventHandler(
//         onJoinChannelSuccess: (connection, elapsed) {
//           isJoined.value = true;
//           print("✅ Joined channel: ${connection.channelId}, UID: ${connection.localUid}");
//         },
//         onUserJoined: (connection, remoteUid, elapsed) {
//           print("👥 Remote user joined: $remoteUid in ${connection.channelId}");
//         },
//         onUserOffline: (connection, remoteUid, reason) {
//           print("🚪 Remote user left: $remoteUid, Reason: $reason");
//         },
//         onLeaveChannel: (connection, stats) {
//           isJoined.value = false;
//           print("👋 Left channel: ${connection.channelId}");
//         },
//         onError: (err, msg) {
//           print("❌ Agora Error [$err]: $msg");
//         }
//       ),
//     );

//    // 

//     isEngineReady.value = true;
//     await _engine.joinChannel(
//       token: "", // Use token in production
//       channelId: channelName,
//       uid: uid,
//       options: const ChannelMediaOptions(),
//     );


//     await _engine.enableAudio();
//     await _engine.setDefaultAudioRouteToSpeakerphone(true);
//     //await _engine.setEnableSpeakerphone(true);
//   }

//   // Set receiver (for PTT)
//   void setReceiver(String userId) {
//     receiverId = userId;
//     print("📡 Set receiver ID: $receiverId");
//     update();
//   }

//   // Toggle mic on/off for PTT
//   void toggleMic(bool on) {
//     if (!isEngineReady.value) {
//       print("⚠️ Engine not initialized yet.");
//       return;
//     }

//     if (receiverId == "0") {
//       print("⚠️ No receiver set.");
//       return;
//     }

//     _engine.muteLocalAudioStream(!on);
//     isMicOn.value = on;

//     if (on) {
//       print("🎤 Mic ON: Sending voice to receiverId=$receiverId on channel=$_currentChannel");
//     } else {
//       print("🔇 Mic OFF: Stopped sending voice");
//     }
//   }

//   // Leave channel
//   Future<void> leaveChannel() async {
//     if (!isEngineReady.value) return;

//     await _engine.leaveChannel();
//     isJoined.value = false;
//     print("👋 Left channel: $_currentChannel, UID: $_localUid");
//   }

//   // Join new channel without reinitializing
//   Future<void> joinNewChannel(String newChannelId) async {
//     if (!isEngineReady.value) {
//       print("⚠️ Engine not initialized yet.");
//       return;
//     }

//     await leaveChannel();
//     _currentChannel = newChannelId;

//     await _engine.joinChannel(
//       token: "",
//       channelId: newChannelId,
//       uid: _localUid,
//       options: const ChannelMediaOptions(),
//     );
//     print("🔄 Switched to new channel: $_currentChannel, UID: $_localUid");
//   }

//   @override
//   void onClose() {
//     if (isEngineReady.value) {
//       _engine.release();
//     }
//     super.onClose();
//     print("🧹 PTTController destroyed and engine released");
//   }
// }
