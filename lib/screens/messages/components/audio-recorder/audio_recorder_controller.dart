import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:marispeaks/api/user_api.dart';
import 'package:marispeaks/config/theme_config.dart';
import 'package:marispeaks/helpers/dialog_helper.dart';
import 'package:marispeaks/screens/messages/controllers/audio_player_controller.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecorderController extends GetxController {
  final String? receiverId;

  AudioRecorderController(this.receiverId);

  final AudioRecorder _record = AudioRecorder();
  RxBool isRecording = false.obs;
  RxBool showPlayback = false.obs;
  RxString audioPath = ''.obs;
  Rx<int> recordingDuration = 0.obs;
  Timer? _recordingTimer;
  Directory? _tempDir;

  @override
  void onInit() async {
    _tempDir = await getTemporaryDirectory();
    super.onInit();
  }

  Future<void> startRecording() async {
    // Request audio recording permission
    if (!await _record.hasPermission()) {
      DialogHelper.showAlertDialog(
        titleColor: errorColor,
        title: Text('permission_denied'.tr),
        content: Text('microphone_permission_denied'.tr),
        actionText: 'open_settings'.tr,
        action: () {
          Get.back();
          Geolocator.openAppSettings();
        },
      );
      return;
    }

    // Start recording to file path
    await _record.start(const RecordConfig(), path: _getAudioPath);

    _startRecordingTimer();
    isRecording.value = true;
    if (receiverId != null) {
      UserApi.updateUserRecordingStatus(true, receiverId!);
    }
  }

  Future<void> stopRecording() async {
    final path = await _record.stop();
    if (path != null) {
      audioPath.value = path;
    }
    isRecording.value = false;
    showPlayback.value = true;
    _recordingTimer?.cancel();
  }

  void _startRecordingTimer() {
    // Cancel existing timer if any
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      recordingDuration.value += 1;
    });
  }

  //
  // <-- Send the recorded audio -->
  //
  Future<void> sendAudio() async {
    final File? audioFile = audioPath.isNotEmpty ? File(audioPath.value) : null;
    if (audioFile == null) {
      DialogHelper.showSnackbarMessage(
          SnackMsgType.error, 'please_record_the_audio_to_send'.tr);
      return;
    }
    debugPrint('sendAudio() -> path: $audioFile');
    Get.back(result: audioFile);
    // Free up the resources
    _closeRecorder();
  }

  void _closeRecorder() {
    _record.dispose();
    _recordingTimer?.cancel();
    // Clear the player controller to init with valid duration
  //  Get.delete<AudioPlayerController>(tag: 'recording_playback', force: true);
  }

  /// Get audio name with .m4a extension.
  String get _getAudioPath {
    if (_tempDir == null) return '';
    final String date = DateTime.now().millisecondsSinceEpoch.toString();
    return '${_tempDir!.path}/recording_$date.m4a';
  }

  String get formattedRecordingDuration {
    int totalSeconds = recordingDuration.value;
    int minutes = (totalSeconds ~/ 60);
    int seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
