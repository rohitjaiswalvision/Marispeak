import 'dart:ui';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:get/get.dart';
import 'package:marispeaks/components/cached_card_image.dart';
import 'package:marispeaks/components/custom_appbar.dart';
import 'package:marispeaks/controllers/auth_controller.dart';
import 'package:marispeaks/models/call.dart';
import 'package:marispeaks/models/user.dart';
import 'package:marispeaks/screens/calling/controller/call_controller.dart';
import 'package:marispeaks/config/theme_config.dart';

import 'components/call_bacground.dart';
import 'components/call_timer.dart';
import '../../components/circle_button.dart';
import 'components/join_call_indicator.dart';
import 'components/local_user_preview.dart';

class VideoCallScreen extends StatelessWidget {
  const VideoCallScreen({
    super.key,
    required this.call,
  });

  final Call call;

  @override
  Widget build(BuildContext context) {
    final CallController controller = Get.put(CallController(call: call));
    final User currentUser = AuthController.instance.currentUser!;

    return PopScope(
      canPop: false, // ✅ disables system + hardware back
      child: GestureDetector(
        // ✅ disables iOS edge-swipe back gesture
        onHorizontalDragUpdate: (_) {},
        behavior: HitTestBehavior.opaque,
        child: Obx(() {
          final int? remoteUid = controller.remoteUid.value;
          final String photoUrl =
              call.isCaller ? call.receiverPhotoUrl : call.callerPhotoUrl;

          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: CustomAppBar(
              title: remoteUid != null ? const CallTimer() : null,
              centerTitle: false,
              backgroundColor: Colors.transparent,
              leading: const SizedBox(), // 👈 hides back icon
            ),
            body: CallBackground(
              remoteUid: remoteUid,
              preview: remoteUid != null
                  ? AgoraVideoView(
                      controller: VideoViewController.remote(
                        rtcEngine: controller.engine,
                        canvas: VideoCanvas(uid: remoteUid),
                        connection: RtcConnection(channelId: call.callerId),
                      ),
                    )
                  : photoUrl.isEmpty
                      ? Container(
                          color:
                              Theme.of(context).colorScheme.primaryContainer,
                        )
                      : CachedCardImage(photoUrl),
              child: Stack(
                children: [
                  SafeArea(
                    child: Column(
                      children: [
                        const Spacer(),
                        Obx(
                          () => LocalUserPreview(
                            child: controller.isLocalUserJoined.value
                                ? AgoraVideoView(
                                    controller: VideoViewController(
                                      rtcEngine: controller.engine,
                                      canvas: const VideoCanvas(uid: 0),
                                    ),
                                  )
                                : currentUser.photoUrl.isEmpty
                                    ? const Icon(
                                        IconlyBold.profile,
                                        color: Colors.white,
                                        size: 60,
                                      )
                                    : CachedCardImage(currentUser.photoUrl),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(defaultPadding),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              CircleButton(
                                color: primaryColor,
                                icon: Icon(
                                  controller.speaker.value
                                      ? IconlyBold.volumeUp
                                      : IconlyBold.volumeOff,
                                  color: Colors.white,
                                ),
                                onPress: controller.onToggleSpeaker,
                              ),
                              CircleButton(
                                color: primaryColor,
                                icon: Icon(
                                  controller.switchCamera.value
                                      ? IconlyBold.video
                                      : IconlyBold.camera,
                                  color: Colors.white,
                                ),
                                onPress: controller.onSwitchCamera,
                              ),
                              CircleButton(
                                color: primaryColor,
                                icon: Icon(
                                  controller.mute.value
                                      ? Icons.mic_off
                                      : IconlyBold.voice,
                                  color: Colors.white,
                                ),
                                onPress: controller.onToggleMute,
                              ),
                              CircleButton(
                                color: Colors.redAccent,
                                icon: const Icon(
                                  IconlyBold.callMissed,
                                  color: Colors.white,
                                ),
                                onPress: controller.onEndCall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (remoteUid == null)
                    Center(
                      child: JoinCallIndicator(
                        call,
                        loadingColor:
                            photoUrl.isEmpty ? Colors.white : primaryColor,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
