import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:get/get.dart';
import 'package:marispeaks/components/cached_card_image.dart';
import 'package:marispeaks/components/cached_circle_avatar.dart';
import 'package:marispeaks/components/custom_appbar.dart';
import 'package:marispeaks/models/call.dart';
import 'package:marispeaks/config/theme_config.dart';

import 'components/call_timer.dart';
import '../../components/circle_button.dart';
import 'components/join_call_indicator.dart';
import 'controller/call_controller.dart';

class VoiceCallScreen extends StatelessWidget {
  const VoiceCallScreen({super.key, required this.call});

  final Call call;

  @override
  Widget build(BuildContext context) {
    final CallController controller = Get.put(CallController(call: call));

    return PopScope(
      canPop: false, // ✅ Disable system back (Android & iOS)
      child: Obx(() {
        final int? remoteUid = controller.remoteUid.value;
        final String photoUrl =
            call.isCaller ? call.receiverPhotoUrl : call.callerPhotoUrl;

        return GestureDetector(
          // ✅ Block iOS edge swipe gesture
          onHorizontalDragUpdate: (_) {},
          behavior: HitTestBehavior.opaque,
          child: Scaffold(
            extendBodyBehindAppBar: true,
            // appBar: CustomAppBar(
            //   centerTitle: false,
            //   backgroundColor: Colors.transparent,
            //   // ✅ Only minimize allowed
            //   onBackPress: () => controller.minimizeCallScreen(),
            // ),
            body: Stack(
              fit: StackFit.expand,
              children: [
                // --- Background Image ---
                if (photoUrl.isNotEmpty) CachedCardImage(photoUrl),

                // --- Blurred Overlay ---
                if (photoUrl.isNotEmpty)
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(color: Colors.black.withOpacity(0.5)),
                  ),

                // --- Default Background (no photo) ---
                if (photoUrl.isEmpty)
                  Container(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    width: double.infinity,
                    height: double.infinity,
                  ),

                // --- Main Content ---
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: defaultPadding,
                      vertical: defaultPadding * 2,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(),

                        // --- Profile Avatar ---
                        CachedCircleAvatar(
                          iconSize: 70,
                          imageUrl: photoUrl,
                          radius: 75,
                        ),
                        const SizedBox(height: 16),

                        // --- Call Status ---
                        remoteUid != null
                            ? const CallTimer()
                            : JoinCallIndicator(call),

                        const Spacer(),

                        // --- Call Controls ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Speaker toggle
                            CircleButton(
                              color:
                                  photoUrl.isEmpty ? greyColor : primaryColor,
                              icon: Icon(
                                controller.speaker.value
                                    ? IconlyBold.volumeUp
                                    : IconlyBold.volumeOff,
                                color: Colors.white,
                              ),
                              onPress: controller.onToggleSpeaker,
                            ),
                            const SizedBox(width: 30),

                            // Mute toggle
                            CircleButton(
                              color:
                                  photoUrl.isEmpty ? greyColor : primaryColor,
                              icon: Icon(
                                controller.mute.value
                                    ? Icons.mic_off
                                    : IconlyBold.voice,
                                color: Colors.white,
                              ),
                              onPress: controller.onToggleMute,
                            ),
                            const SizedBox(width: 30),

                            // End call button
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

                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
