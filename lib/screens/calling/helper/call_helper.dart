import 'package:marispeaks/api/call_history_api.dart';
import 'package:get/get.dart';
import 'package:marispeaks/api/message_api.dart';
import 'package:marispeaks/controllers/auth_controller.dart';
import 'package:marispeaks/models/call.dart';
import 'package:marispeaks/models/user.dart';
import 'package:marispeaks/routes/app_routes.dart';
import 'package:marispeaks/services/push_notification_service.dart';

abstract class CallHelper {
  //
  // Call Helper Methods
  //

  // Make video/voice call
  static Future<void> makeCall({
    required bool isVideo,
    required User user,
  }) async {
    // Get current user
    final User currentUser = AuthController.instance.currentUser!;

    // Get call instance
    final Call call = Call(
      isVideo: isVideo,
      // Set caller info
      callerId: currentUser.userId,
      callerName: currentUser.fullname,
      callerPhotoUrl: currentUser.photoUrl,
      // Set receiver info
      receiverName: user.fullname,
      receiverPhotoUrl: user.photoUrl,
    );

    // Get notification body
    final String body =
        isVideo ? 'incomming_video_call'.tr : 'incomming_voice_call'.tr;

    // Send push notification call
    PushNotificationService.sendNotification(
      type: NotificationType.call,
      title: currentUser.fullname,
      body: body,
      deviceToken: user.deviceToken,
      call: call.toMap(),
    );

    // Vars
    dynamic result;
    final Map<String, Call> arguments = {'call': call};

    // Save call history
    CallHistoryApi.saveCall(isVideo: isVideo, receiver: user);

    // Check call type
    if (isVideo) {
      // Go to video call page
      result = await Get.toNamed(AppRoutes.videoCall, arguments: arguments);
    } else {
      // Go to voice call page
      result = await Get.toNamed(AppRoutes.voiceCall, arguments: arguments);
    }

    // Check result to send missed call message
    if (result == "Reject") {
      Future.wait([
        MessageApi.sendMissedCallMessage(isVideo: isVideo, receiver: user),
        CallHistoryApi.saveMissedCall(isVideo: isVideo, receiver: user),
      ]);
      print("Missed call status sent");
    }
    else {
      print("Results: $result");
    }
  }

  // Format the call time
  static String formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
