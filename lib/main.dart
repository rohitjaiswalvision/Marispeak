import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:marispeaks/config/app_config.dart';
import 'package:marispeaks/config/environment.dart';
import 'package:marispeaks/controllers/preferences_controller.dart';
import 'package:marispeaks/helpers/notification_helper.dart';
import 'package:marispeaks/helpers/settings_provider.dart';
import 'package:marispeaks/i18n/app_languages.dart';
import 'package:marispeaks/models/call.dart';
import 'package:marispeaks/routes/app_pages.dart';
import 'package:marispeaks/routes/app_routes.dart';
import 'package:marispeaks/screens/calling/controller/call_controller.dart';
import 'package:marispeaks/screens/home/CustomBottomSection.dart';
import 'package:marispeaks/screens/home/LatLngPoint.dart';
import 'package:marispeaks/screens/home/MainScreenUI.dart';
import 'package:marispeaks/screens/home/SavedRoute.dart';
import 'package:marispeaks/screens/home/ais_service.dart';
import 'package:marispeaks/screens/messages/controllers/message_controller.dart';
import 'package:marispeaks/screens/ptt/websocket_ptt_controller.dart';
import 'package:marispeaks/theme/app_theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:marispeaks/models/call.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'provider/weatherProvider.dart';
import 'package:marispeaks/services/voip_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final GlobalKey<ScaffoldMessengerState> rootScaffoldKey =
    GlobalKey<ScaffoldMessengerState>();

int? _incomingCallNotificationId;

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final data = message.data;
  final notificationBody = message.notification?.body?.toLowerCase() ?? '';
  final chatId = data['chatId'] ?? '';
  final groupId = data['groupId'] ?? '';
  final senderId = data['senderId'] ?? '';
  final type = data['type'] ?? '';
  final seenByRaw = data['seenBy'];

  // ✅ Parse seenBy safely
  final List<String> seenBy = (seenByRaw != null && seenByRaw.isNotEmpty)
      ? List<String>.from(jsonDecode(seenByRaw))
      : [];

  // ✅ Fetch current user safely (no UI access in background isolate)
  final currentUser = FirebaseAuth.instance.currentUser?.uid ?? '';
// ✅ Skip notification if user is already in that chat
  if (MessageController.currentOpenChatId != null &&
      (MessageController.currentOpenChatId == chatId ||
          MessageController.currentOpenChatId == senderId && type != 'call')) {
    print('[Notification] Skipping notification — chat already open');
    return;
  }

  // ✅ Special group handling
  if (groupId == "1e8bf062-772f-42b3-9a09-7f0021f936db" ||
      chatId == "1e8bf062-772f-42b3-9a09-7f0021f936db") {
    if (notificationBody.contains("group msg")) {
      WebSocketPTTController().joinGroup(chatId);
    }

    if (notificationBody.contains("group ptt ends")) {
      // WebSocketPTTController().joinGroup(currentUser);
    }

    print(
        '[FCM] onMessage (background) - abc group msg allowed: ${message.data}');
    showLocalNotification(message);
  } else {
    if (notificationBody.contains("group msg")) {
      WebSocketPTTController().joinGroup(chatId);
    }

    if (notificationBody.contains("group ptt ends")) {
      // WebSocketPTTController().joinGroup(currentUser);
    }

    print('[FCM] group msg: $groupId');

    showLocalNotification(message);
  }

  // ✅ Handle missed / rejected / call types
  if (notificationBody.contains("you missed a")) {
    await handleCallRejected();
    return;
  }

  if (notificationBody.contains("rejected")) {
    print('📞 Call Rejected');
    await handleCallRejected();
    if (Get.isRegistered<CallController>()) {
      final controller = Get.find<CallController>();
      await controller.onRemoteRejected();
    }
    return;
  }

  if (type == 'call') {
    await NotificationHelper.onNotificationClick(payload: data);
  }

  if (type == 'ptt') {
    print('[FCM] Background PTT received for group $groupId');
    WebSocketPTTController().handlePushConnect(groupId, currentUser);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Print environment info at startup
  printEnvironmentInfo();

  // ✅ Store PTT server URL in UserDefaults for native code to use
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
      'ptt_server_url', Environment.current.pttServerUrl);
  print('📍 Stored PTT server URL: ${Environment.current.pttServerUrl}');

  final appDocDir = await getApplicationDocumentsDirectory();
  Hive.init(appDocDir.path);
  Hive.registerAdapter(LatLngPointAdapter());
  Hive.registerAdapter(SavedRouteAdapter());
  await Hive.openBox<SavedRoute>('savedRoutes');

  // Get.put(WebSocketPTTController());
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await setupLocalNotifications();
  await setupFirebaseMessaging();

  // ✅ Initialize VoIP service (iOS only — wakes app from background for PTT)
  await VoIPService().initialize();

  VoIPService().onVoIPPushReceived = (payload) {
    print('[VoIP] Push Received: $payload');
    final groupId = payload['groupId'];
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (groupId != null && groupId.isNotEmpty) {
      WebSocketPTTController().handlePushConnect(groupId, userId);
    }
  };

  VoIPService().onCallAnswered = () {
    print('[VoIP] Call Answered on iOS lockscreen');
  };

  VoIPService().onCallEnded = () {
    print('[VoIP] Call Ended on iOS lockscreen');
  };

  // ✅ Check for any VoIP push payload stored while app was locked/suspended
  // This catches the case where iOS woke the app but Flutter wasn't ready yet
  WidgetsBinding.instance.addObserver(_VoIPResumeObserver());

  Get.put(PreferencesController(), permanent: true);

  // Check if app was opened from a terminated state via notification
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    print('[FCM] getInitialMessage: ${initialMessage.data}');
    NotificationHelper.queueInitialCallIfNeeded(initialMessage.data);
  }

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AISService()),
      ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ChangeNotifierProvider(create: (_) => WeatherProvider()),
    ],
    child: const MyApp(),
  ));
}

/// ✅ Checks for any VoIP push payload stored in UserDefaults while app was locked.
/// Called every time the app resumes from background.
class _VoIPResumeObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[VoIP] App resumed — checking for pending push payload...');
      VoIPService().checkPendingVoIPPayload();
    }
  }
}

class MyApp extends GetView<PreferencesController> {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    return GetMaterialApp(
      locale: controller.locale.value,
      fallbackLocale: const Locale('en'),
      translations: AppLanguages(),
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(context).lightTheme,
      darkTheme: AppTheme.of(context).darkTheme,
      themeMode: controller.isDarkMode.value ? ThemeMode.dark : ThemeMode.light,
      initialRoute: AppRoutes.splash,
      getPages: AppPages.pages,
    );
  }
}

Future<void> setupLocalNotifications() async {
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final DarwinInitializationSettings iosInit = DarwinInitializationSettings();
  final InitializationSettings initSettings =
      InitializationSettings(android: androidInit, iOS: iosInit);

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload != null) {
        try {
          final data = jsonDecode(response.payload!);
          print('[NotificationHelper] Local notification clicked');

          // Check if it's a call notification
          if (data['type'] == 'call') {
            // Handle call - don't open chat
            NotificationHelper.onNotificationClick(payload: data);
          } else {
            // Handle chat message - open chat
            NotificationHelper.onNotificationClick(payload: data);
            NotificationHelper.openChatFromPayload(data);
          }
        } catch (e) {
          print('[NotificationHelper] Payload decode error: $e');
        }
      }
    },
  );
}

Future<void> setupFirebaseMessaging() async {
  final FirebaseMessaging messaging = FirebaseMessaging.instance;
  // ✅ Register background handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  // ✅ Request permissions (iOS)
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  // ✅ Print tokens
  final token = await messaging
      .getToken()
      .timeout(const Duration(seconds: 3), onTimeout: () => '');
  print('✅ FCM Token: $token');
  final apnsToken = await messaging
      .getAPNSToken()
      .timeout(const Duration(seconds: 3), onTimeout: () => null);
  print('📱 APNs Token: $apnsToken');

  // ✅ Foreground message listener
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    final data = message.data;
    final notificationBody = message.notification?.body?.toLowerCase() ?? '';
    final chatId = data['chatId'] ?? '';
    final groupId = data['groupId'] ?? '';
    final type = data['type'] ?? '';
    final seenByRaw = data['seenBy'];

    // SKIP NOTIFICATION IF CHAT IS OPEN
    if (MessageController.currentOpenChatId != null) {
      final openChat = MessageController.currentOpenChatId!;
      final chatId = data['chatId'] ?? '';
      final senderId = data['senderId'] ?? '';

      if (notificationBody.contains("rejected") && type != 'call') {
        print('[Notification] Not skipped — Call rejected!');
      } else {
        if (openChat == chatId || openChat == senderId) {
          print('[Notification] Skipping — Chat already open');
          return;
        }
      }
    }
    // ✅ Parse seenBy safely
    List<String> seenBy = [];
    if (seenByRaw != null && seenByRaw.isNotEmpty) {
      try {
        seenBy = List<String>.from(jsonDecode(seenByRaw));
      } catch (e) {
        print('[FCM] seenBy parsing failed: $e');
      }
    }

    // ✅ Safe user ID access (foreground only)
    final String currentUser =
        customBottomSection.currentState!.currentUser.userId;

    // ✅ Specific group/channel logic
    if (groupId == "1e8bf062-772f-42b3-9a09-7f0021f936db" ||
        chatId == "1e8bf062-772f-42b3-9a09-7f0021f936db") {
      if (notificationBody.contains("group msg")) {
        WebSocketPTTController().joinGroup(chatId);
      }

      if (notificationBody.contains("group ptt ends")) {
        // WebSocketPTTController().joinGroup(currentUser);
      }

      print(
          '[FCM] onMessage (foreground) - abc group msg allowed: ${message.data}');
      showLocalNotification(message);
    } else {
      if (notificationBody.contains("group msg")) {
        WebSocketPTTController().joinGroup(chatId);
      }

      if (notificationBody.contains("group ptt ends")) {
        // WebSocketPTTController().joinGroup(currentUser);
      }

      print('[FCM] group msg: $groupId');
      showLocalNotification(message);
    }

    // ✅ Handle missed call
    if (notificationBody.contains("you missed a")) {
      await handleCallRejected();
      return;
    }

    // ✅ Handle rejected call
    if (notificationBody.contains("rejected")) {
      print('📞 Call Rejected');
      await handleCallRejected();
      if (Get.isRegistered<CallController>()) {
        final controller = Get.find<CallController>();
        await controller.onRemoteRejected();
      }
      return;
    }

    // ✅ Handle incoming call
    if (type == 'call') {
      await NotificationHelper.onNotificationClick(payload: data);
    }
  });

  // ✅ Handle when user taps on a notification
  // ✅ Handle when user taps on a notification
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    final data = message.data;

    // Check if it's a call notification
    if (data['type'] == 'call') {
      // Handle call - don't open chat
      NotificationHelper.onNotificationClick(payload: data);
    } else {
      // Handle chat message - open chat
      NotificationHelper.onNotificationClick(payload: data);
      NotificationHelper.openChatFromPayload(data);
    }
  });
}

void showLocalNotification(RemoteMessage message) async {
  final String type = message.data['type'] ?? '';

  // ✅ Skip local notification for calls when app is in foreground. The Incoming Call screen will handle the UI and the ringtone!
  if (type == 'call') {
    print(
        '[Notification] Call notification skipped because app is in foreground and will open Incoming Call screen.');
    return; // skip showing notification and sound
  }

  AndroidNotificationDetails androidDetails;
  if (type == 'call') {
    _incomingCallNotificationId = 1000;
    androidDetails = const AndroidNotificationDetails(
      'Marispeak_channel',
      'Marispeak Notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      sound: RawResourceAndroidNotificationSound('tone'),
      playSound: true,
    );
  } else {
    androidDetails = const AndroidNotificationDetails(
      'Marispeak_channel',
      'Marispeak Notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
    );
  }

  DarwinNotificationDetails iosDetails;
  if (type == 'call') {
    iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'marispeak_ringtone.caf',
    );
  } else {
    iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );
  }

  final NotificationDetails notificationDetails =
      NotificationDetails(android: androidDetails, iOS: iosDetails);

  await flutterLocalNotificationsPlugin.show(
    _incomingCallNotificationId ?? 0,
    message.notification?.title ?? "New Message",
    message.notification?.body ?? "",
    notificationDetails,
    payload: jsonEncode(message.data),
  );
}

Future<void> handleCallRejected() async {
  print('[Call] Call rejected, removing notification');

  // Remove local notification
  if (_incomingCallNotificationId != null) {
    await flutterLocalNotificationsPlugin.cancel(_incomingCallNotificationId!);

    // Save the ID to SharedPreferences BEFORE clearing it
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'incomingCallNotificationId', _incomingCallNotificationId!);

    _incomingCallNotificationId = null;
  }

  // Close any in-app incoming call screen
  NotificationHelper.closeIncomingCallIfVisible();
}
