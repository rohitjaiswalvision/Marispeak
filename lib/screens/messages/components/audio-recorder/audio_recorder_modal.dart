import 'package:flutter/material.dart';
import 'package:marispeaks/api/user_api.dart';
import 'package:marispeaks/components/svg_icon.dart';
import 'package:marispeaks/config/theme_config.dart';
import 'package:marispeaks/controllers/auth_controller.dart';
import 'package:marispeaks/screens/messages/controllers/audio_player_controller.dart';
import 'package:get/get.dart';

import 'audio_recorder_controller.dart';
import 'components/recording_playback.dart';

class AudioRecorderModal extends StatefulWidget {
  const AudioRecorderModal(this.receiverId, {super.key});

  final String? receiverId;

  @override
  State<AudioRecorderModal> createState() => _AudioRecorderModalState();
}

class _AudioRecorderModalState extends State<AudioRecorderModal> {
  @override
  void dispose() {
    // Free up the controller resources.
    Get.delete<AudioRecorderController>(force: true);
   // Get.delete<AudioPlayerController>(tag: 'recording_playback', force: true);
    if (widget.receiverId != null &&
        AuthController.instance.currentUser!.isRecording) {
      UserApi.updateUserRecordingStatus(false, widget.receiverId!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Init Audio Recorder Controller
    final AudioRecorderController controller = Get.put(
      AudioRecorderController(widget.receiverId),
    );

    return Obx(() {
      final bool isRecording = controller.isRecording.value;

      return Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(defaultRadius),
            topRight: Radius.circular(defaultRadius),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: defaultPadding,
          vertical: defaultPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Show Recording Controls
            if (isRecording) _buildRecordingControls(context, controller),
            // 2. Playback Controls
        //    if (controller.showPlayback.value)
             // RecordingPlayback(fileUrl: controller.audioPath.value),
            //
            const SizedBox(height: 8),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Delete Recorded Audio
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.cancel, color: Colors.grey, size: 35),
                ),

                // Start/Stop Recording
                if (!controller.showPlayback.value)
                  IconButton(
                    onPressed: () {
                      if (isRecording) {
                        controller.stopRecording();
                      } else {
                        controller.startRecording();
                      }
                    },
                    icon: Icon(
                      isRecording ? Icons.stop : Icons.mic,
                      color: Colors.red,
                      size: 32,
                    ),
                  ),
                // Send Audio
                IconButton(
                  onPressed: () => controller.sendAudio(),
                  padding: EdgeInsets.zero,
                  icon: const CircleAvatar(
                    radius: 25,
                    backgroundColor: primaryColor,
                    child: SvgIcon(
                      'assets/icons/send.svg',
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      );
    });
  }

  Widget _buildRecordingControls(
      BuildContext context, AudioRecorderController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          controller.formattedRecordingDuration,
          style:
              Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 30),
        ),
      ],
    );
  }
}
