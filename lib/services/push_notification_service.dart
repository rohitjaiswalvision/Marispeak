import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:marispeaks/models/message.dart';
import 'package:marispeaks/controllers/auth_controller.dart';
import 'package:get/get.dart';

enum NotificationType { alert, call, message, group }

abstract class PushNotificationService {
  //
  // Firebase Push Notifications Service
  //
  static final _functions = FirebaseFunctions.instance;

  /// Send push notification
  static Future<void> sendNotification({
  required NotificationType type,
  required String title,
  required String body,
  required String deviceToken,
  String? chatId, // ✅ optional
  bool? isGroup,
  Map<String, dynamic>? call,
  Map<String, dynamic>? data, // ✅ Add this
}) async {
  try {
    await _functions.httpsCallable('sendPushNotification').call({
      'type': type.name,
      'title': title,
      'body': body,
      'chatId': chatId,
      'deviceToken': deviceToken,
      'call': call ?? {},
      'data': data ?? {}, // ✅ Include it here
      'senderId': AuthController.instance.currentUser!.userId,
    });
    debugPrint('sendPushNotification() -> success');
  } catch (e) {
    debugPrint('sendPushNotification() -> error: $e');
  }
}


  static String getMessageType(MessageType type) {
    return switch (type) {
      MessageType.text => '📩 ${'new_text_message'.tr}',
      MessageType.image => '📷 ${'photo'.tr}',
      MessageType.gif => '🎬 GIF',
      MessageType.audio => '🎵 ${'audio'.tr}',
      MessageType.video => '📹 ${'video'.tr}',
      MessageType.doc => '📄 ${'document'.tr}',
      MessageType.location => '📍 ${'location_shared'.tr}',
      _ => '',
    };
  }
}
