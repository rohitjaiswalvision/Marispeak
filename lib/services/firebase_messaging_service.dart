import 'dart:io';

import 'package:marispeaks/helpers/notification_helper.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract class FirebaseMessagingService {
  ///
  /// Handle incoming notifications while the app is in the Foreground
  ///
  static Future<void> initFirebaseMessagingUpdates() async {
    // Request notifications permission
    await _requestNotificationsPermission();

    if (Platform.isAndroid) {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const AndroidNotificationChannel callingChannel = AndroidNotificationChannel(
        'calling_channel', // id
        'Incoming Calls', // title
        description: 'Used for incoming audio and video calls.',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('tone'),
      );
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(callingChannel);
    }

    // Get inicial message if the application
    // has been opened from a terminated state.
    final RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    // Check notification data
    if (initialMessage != null) {
      // Debug
      debugPrint('getInitialMessage() -> data: ${initialMessage.data}');
      // Handle notification click
      NotificationHelper.onNotificationClick(
        openRoute: true,
        payload: initialMessage.data,
      );
    }

    // Returns a [Stream] that is called when a user
    // presses a notification message displayed via FCM.
    // Note: A Stream event will be sent if the app has
    // opened from a background state (not terminated).
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      // Debug
      debugPrint('onMessageOpenedApp() -> data: ${message.data}');
      // Handle notification click
      NotificationHelper.onNotificationClick(
        openRoute: true,
        payload: message.data,
      );
    });

    // Listen for incoming push notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      // Debug
      debugPrint('onMessage() -> data: ${message.data}');

      // Handle notification click
      NotificationHelper.onNotificationClick(payload: message.data);
    });
  }

  /// Request push notifications permission.
  static Future<void> _requestNotificationsPermission() async {
    // Request permission for iOS devices
    if (Platform.isIOS) {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final AuthorizationStatus status = settings.authorizationStatus;
      // Debug
      debugPrint('requestNotificationsPermission() for iOS -> $status');
    } else {
      // <-- Android permissions -->

      final PermissionStatus status = await Permission.notification.request();
      if (status.isPermanentlyDenied) {
        // Permission permanently denied, you can open the app settings to allow permissions
        await openAppSettings();
      }
      // Debug
      debugPrint('requestNotificationsPermission() for Android -> $status');
    }
  }
}
