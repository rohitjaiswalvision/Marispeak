import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:marispeaks/api/user_api.dart';
import 'package:marispeaks/components/app_logo.dart';
import 'package:marispeaks/config/app_config.dart';
import 'package:marispeaks/helpers/routes_helper.dart';
import 'package:marispeaks/main.dart';
import 'package:marispeaks/models/call.dart';
import 'package:marispeaks/models/user.dart';
import 'package:marispeaks/routes/app_routes.dart';
import 'package:marispeaks/screens/messages/controllers/message_controller.dart';
import 'dialog_helper.dart';

abstract class NotificationHelper {
  /// Used to temporarily store call if mapHome is not yet ready
  static Map<String, dynamic>? _pendingCallPayload;
  /// Called inside mapHome after it's fully loaded to trigger pending call
  static void showPendingCallIfAny() {
    if (_pendingCallPayload != null) {
      print('[NotificationHelper] Showing queued incoming call UI...');
      onNotificationClick(payload: _pendingCallPayload!);
      _pendingCallPayload = null;
    }
  }

  /// Called ONLY from main.dart if app was launched from terminated state
  static void queueInitialCallIfNeeded(Map<String, dynamic> data) {
    if (data['type'] == 'call') {
      print('[NotificationHelper] Queued call from terminated state');
      _pendingCallPayload = data;
    }
  }

  /// Unified notification tap handler — safely opens Incoming Call UI
  static Future<void> onNotificationClick({
    bool openRoute = false,
    Map<String, dynamic>? payload,
  }) async {
    if (payload == null || payload['type'] == null) {
      print('[NotificationHelper] Invalid or empty payload.');
      return;
    }

    final String type = payload['type'] ?? '';
    final String title = payload['title'] ?? '';
    final String message = payload['message'] ?? '';

    print('[NotificationHelper] Notification Clicked');
    print('[NotificationHelper] Type: $type');
    print('[NotificationHelper] Payload: $payload');

    switch (type) {
      case 'call':
        try {
          final callData = payload['call'];
          final Map<String, dynamic> callMap =
              callData is String ? jsonDecode(callData) : Map<String, dynamic>.from(callData);

          final Call call = Call.fromMap(data: callMap);
    // Before navigating to Incoming Call screen
      await flutterLocalNotificationsPlugin.cancel(0);
         // NEW: Only defer call if app was killed and not yet reached mapHome
final bool appJustLaunched = _pendingCallPayload != null;

if (appJustLaunched && Get.currentRoute != AppRoutes.mapHome) {
  print('[NotificationHelper] App just launched, not on mapHome — queuing call...');
  _pendingCallPayload = payload;
  return;
}


          // 🕐 Slight delay for smoother transition
          Future.delayed(const Duration(milliseconds: 500), () {
            if (Get.currentRoute != AppRoutes.incomingCall) {
              Get.toNamed(AppRoutes.incomingCall, arguments: {'call': call});
              print('[NotificationHelper] Navigated to Incoming Call Screen');
            } else {
              print('[NotificationHelper] Already on Incoming Call Screen');
            }
          });
        } catch (e) {
          print('[NotificationHelper] Failed to parse call payload: $e');
        }
        break;

      case 'alert':
        closeIncomingCallIfVisible();
        DialogHelper.showAlertDialog(
          icon: const AppLogo(width: 35, height: 35),
          title: title.isNotEmpty ? Text(title) : const Text(AppConfig.appName),
          content: Text(message),
          actionText: 'OK'.tr,
          action: () => Get.back(),
          showCancelButton: false,
        );
        break;

      default:
        closeIncomingCallIfVisible();
        print('[NotificationHelper] Unknown notification type: $type');
    }
  }

  /// Closes the incoming call screen if it’s currently open
  static void closeIncomingCallIfVisible() {
    if (Get.currentRoute == AppRoutes.incomingCall) {
      print('[NotificationHelper] Closing Incoming Call Screen due to other notification');
      if (Get.context != null) {
        Navigator.of(Get.context!).pop();
      }
    }
  }


/// Always opens a person-to-person chat, named as the sender (not a group)
static Future<void> openChatFromPayload(Map<String, dynamic> payload) async {
  try {
    final String senderId = payload['senderId'] ?? '';
    final String title = payload['title'] ?? 'Unknown';

    if (senderId.isEmpty) {
      print('[NotificationHelper] No senderId found in payload.');
      return;
    }

    print('[NotificationHelper] Opening person chat with: $title ($senderId)');

    // Always treat as a user chat (ignore isGroup / groupId)
    final User user = User(
      userId: senderId,
      fullname: title,
      photoUrl: '',
    );

    // Check if already inside same chat
    final messageController = Get.isRegistered<MessageController>()
        ? Get.find<MessageController>()
        : null;

    if (messageController != null &&
        !messageController.isGroup &&
        messageController.user?.userId == senderId) {
      print('[NotificationHelper] Already in chat with $senderId');
      return;
    }
 final userx = await UserApi.getUser(senderId);

    // Always go directly to personal chat
    RoutesHelper.toMessages(user: userx);

    print('[NotificationHelper] ✅ Navigated to person chat with $title');
  } catch (e) {
    print('[NotificationHelper] ❌ Failed to open person chat: $e');
  }
}

  
}
