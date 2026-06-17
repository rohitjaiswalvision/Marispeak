import 'dart:ui';
import 'dart:async';
import 'dart:io';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:get/get.dart';
import 'package:marispeaks/api/user_api.dart';
import 'package:marispeaks/components/cached_card_image.dart';
import 'package:marispeaks/components/cached_circle_avatar.dart';
import 'package:marispeaks/components/custom_appbar.dart';
import 'package:marispeaks/components/circle_button.dart';
import 'package:marispeaks/config/app_config.dart';
import 'package:marispeaks/config/theme_config.dart';
import 'package:marispeaks/controllers/auth_controller.dart';
import 'package:marispeaks/helpers/dialog_helper.dart';
import 'package:marispeaks/helpers/routes_helper.dart';
import 'package:marispeaks/main.dart';
import 'package:marispeaks/models/call.dart';
import 'package:marispeaks/models/user.dart';
import 'package:marispeaks/routes/app_routes.dart';
import 'package:marispeaks/screens/calling/controller/call_controller.dart';
import 'package:marispeaks/screens/home/CustomBottomSection.dart';
import 'package:marispeaks/screens/ptt/agora_controller.dart';
import 'package:marispeaks/services/push_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:audioplayers/audioplayers.dart';

class IncommingCallScreen extends StatefulWidget {
  const IncommingCallScreen({super.key, required this.call});

  final Call call;

  @override
  State<IncommingCallScreen> createState() => _IncommingCallScreenState();
}

class _IncommingCallScreenState extends State<IncommingCallScreen> {
  bool _hideUI = false;
  AudioPlayer? _audioPlayer;

  final AgoraController agoraController = AgoraController();

  @override
  void initState() {
    super.initState();
       cancelIncomingCallNotificationIfAny();

    ringtone();

  }

  Future<int?> getSavedIncomingCallNotificationId() async {
  final prefs = await SharedPreferences.getInstance();
  // returns null if key doesn't exist
  return prefs.getInt('incomingCallNotificationId');
}

Future<void> cancelIncomingCallNotificationIfAny() async {
  final int? notificationId = await getSavedIncomingCallNotificationId();

  if (notificationId != null) {
    await flutterLocalNotificationsPlugin.cancel(notificationId);
    print('[Notification] Cancelled incoming call notification: $notificationId');
    
    // Clear it after canceling
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('incomingCallNotificationId');
  }
}

  Future<void> ringtone() async {
    
    playLoopingRingtone();
  }


    Future<void> playLoopingRingtone() async {
      _audioPlayer = AudioPlayer();

      await _audioPlayer!.setAudioContext(
    AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: true,
        contentType: AndroidContentType.speech,
        usageType: AndroidUsageType.voiceCommunication,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playAndRecord,
        options: {AVAudioSessionOptions.defaultToSpeaker}, // Use set, not list
      ),
    ),
  );
  
      
    customBottomSection.currentState?.forceSpeakerOnIOS();
    
      await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer?.play(AssetSource('sounds/tone.mp3'),
          volume: 1.0);
    }

  @override
  void dispose() async {
    
    _audioPlayer?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String photoUrl = widget.call.callerPhotoUrl;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const CustomAppBar(
        centerTitle: false,
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image with blur
          CachedCardImage(photoUrl),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
          if (photoUrl.isEmpty)
            Container(
              color: Theme.of(context).colorScheme.primaryContainer,
              width: double.infinity,
              height: double.infinity,
            ),

          // Incoming Call UI
          Visibility(
            visible: !_hideUI,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: defaultPadding,
                  vertical: defaultPadding * 2,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),

                    CachedCircleAvatar(
                      iconSize: 70,
                      imageUrl: photoUrl,
                      radius: 75,
                    ),
                    const SizedBox(height: 16),

                    Text(
                      widget.call.isVideo
                          ? 'incomming_video_call'.tr
                          : 'incomming_voice_call'.tr,
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      widget.call.callerName,
                      style: Theme.of(context).textTheme.headlineSmall!.copyWith(color: Colors.white54),
                    ),
                    const SizedBox(height: 50),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Chat Button
                        CircleButton(
                          icon: const Icon(IconlyBold.chat, color: Colors.white),
                          onPress: () async {
                            final User? user = await UserApi.getUser(widget.call.callerId);
                            if (user == null) {
                              DialogHelper.showSnackbarMessage(SnackMsgType.error, 'user_account_not_found'.tr);
                      _audioPlayer?.stop();
                              if (mounted) Navigator.pop(context);
                              
                              return;
                            }


                      // ✅ Send push notification to caller
                      final User currentUser = AuthController.instance.currentUser!;
                      final User? caller = await UserApi.getUser(widget.call.callerId);

                      if (caller != null && caller.deviceToken.isNotEmpty) {
                        await PushNotificationService.sendNotification(
                          type: NotificationType.message,
                          title: currentUser.fullname,
                          body: 'Rejected', // message body
                          deviceToken: caller.deviceToken,
                        );
                      }
                      _audioPlayer?.stop();
                      setState(() => _hideUI = true); // hide UI
                      if (mounted) Navigator.pop(context); // Close screen

                            RoutesHelper.toMessages(user: user);
                          },
                        ),
                        const SizedBox(width: 16),

                        // Accept Button
                        SizedBox(
                          height: 50,
                          width: 150,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              elevation: 0,
                            ),
                            onPressed: () {
                              
                      _audioPlayer?.stop();
                              final route = widget.call.isVideo
                                  ? AppRoutes.videoCall
                                  : AppRoutes.voiceCall;
                              Get.offNamed(route, arguments: {'call': widget.call});
                            },
                            child: Shimmer.fromColors(
                              baseColor: Colors.white,
                              highlightColor: greyColor,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(IconlyBold.call, color: Colors.white),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      'answer_call'.tr,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Reject Button
                        CircleButton(
                          icon: const Icon(IconlyBold.callMissed, color: Colors.redAccent),
                                            onPress: () async {
                      setState(() => _hideUI = true); // hide UI
                      _audioPlayer?.stop();

                      await Future.delayed(const Duration(milliseconds: 500));

                      // ✅ Send push notification to caller
                      final User currentUser = AuthController.instance.currentUser!;
                      final User? caller = await UserApi.getUser(widget.call.callerId);

                      if (caller != null && caller.deviceToken.isNotEmpty) {
                        await PushNotificationService.sendNotification(
                          type: NotificationType.message,
                          title: currentUser.fullname,
                          body: 'Rejected', // message body
                          deviceToken: caller.deviceToken,
                        );
                      }
                      if (mounted) Navigator.pop(context); // Close screen
                    },
                  ),
                      ],
                    ),

                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
