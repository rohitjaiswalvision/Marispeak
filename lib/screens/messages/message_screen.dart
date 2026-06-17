import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:marispeaks/api/message_api.dart';
import 'package:marispeaks/api/user_api.dart';
import 'package:marispeaks/components/loading_indicator.dart';
import 'package:marispeaks/components/no_data.dart';
import 'package:marispeaks/config/theme_config.dart';
import 'package:marispeaks/controllers/auth_controller.dart';
import 'package:marispeaks/controllers/preferences_controller.dart';
import 'package:marispeaks/helpers/routes_helper.dart';
import 'package:marispeaks/models/group.dart';
import 'package:marispeaks/models/message.dart';
import 'package:marispeaks/models/user.dart';
import 'package:marispeaks/helpers/date_helper.dart';
import 'package:flutter/material.dart';
import 'package:marispeaks/screens/home/MainScreenUI.dart';
import 'package:marispeaks/screens/ptt/agora_controller.dart';
import 'package:marispeaks/screens/ptt/websocket_ptt_controller.dart';
import 'package:marispeaks/services/push_notification_service.dart';
import 'package:marispeaks/tabs/groups/components/update_message.dart';
import 'package:get/get.dart';
import 'package:marispeaks/screens/home/CustomBottomSection.dart';
import 'package:marispeaks/tabs/groups/controllers/group_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'components/appbar_tools.dart';
import 'components/encrypted_notice.dart';
import 'components/msg_appbar_tools.dart';
import 'controllers/block_controller.dart';
import 'components/bubble_message.dart';
import 'components/chat_input_field.dart';
import 'components/group_date_separator.dart';
import 'components/scroll_down_button.dart';
import 'controllers/message_controller.dart';

class MessageScreen extends StatelessWidget {
  const MessageScreen({
    super.key,
    required this.isGroup,
    this.user,
    this.groupId,
  });

  final bool isGroup;
  final User? user;
  final String? groupId;



@override
Widget build(BuildContext context) {
  // Init controllers
  final MessageController controller = Get.put(
    MessageController(isGroup: isGroup, user: user),
  );

  String? myid = customBottomSection.currentState?.currentUser.userId;

  // ✅ Fix: Define userOrGroupId safely
  final String userOrGroupId = isGroup
      ? groupId ?? '' // fallback to empty string if groupId is null
      : user?.userId ?? ''; // fallback to empty string if user is null

  print('group or user id $userOrGroupId');

  Get.put(BlockController(user?.userId));

  // Find instance
  final PreferencesController prefController = Get.find();

  // Check group
  if (isGroup) {
    prefController.getGroupWallpaperPath(
      controller.selectedGroup!.groupId,
    );
  } else {
    prefController.getChatWallpaperPath();
  }

  return Obx(
    () {
      // Get selected group instance
      Group? group = controller.selectedGroup;

      final Widget appBar = controller.selectedMessage.value != null
          ? const MsgAppBarTools()
          : AppBarTools(isGroup: isGroup, user: user, group: group);

      return Scaffold(
        appBar: appBar as PreferredSizeWidget,
        body: SafeArea( // ✅ Wrapped with SafeArea
          child: Obx(
            () {
              // Get wallpaper path
              final String? wallpaperPath = isGroup
                  ? prefController.groupWallpaperPath.value
                  : prefController.chatWallpaperPath.value;

              return Container(
                decoration: BoxDecoration(
                  image: wallpaperPath != null
                      ? DecorationImage(
                          image: FileImage(File(wallpaperPath)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        // Messages List
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: _buildMessagesList(wallpaperPath),
                          ),
                        ),
                        // Chat input field
                        ChatInputField(
                          user: user,
                          group: group,
                        ),
                      ],
                    ),

                    // Push-to-talk mic button
                    controller.isTextMsg.value == false
                        ? Positioned(
                        bottom: Platform.isAndroid ? 5 : 25,
                            right: 0,
                            child: PushToTalkMicButton(
                              onPointerDown: () async {
                                    bool hasAccess = await customBottomSection.currentState!.isSubscribed();
       if (!hasAccess){
    // ✅ Check daily limit / subscription inside handleLimitedButtonPress
    print("Checking PTT button limit/subscription...");
    final allowed = await mainScreenKey.currentState!
        .handleLimitedButtonPress(context: context, buttonId: 'PTT');

    if (!allowed) {
      print("Button press blocked: limit or subscription restriction");
      return; // stop if limit or subscription not allowed
    }
           }


                                      if (isGroup) {
                                  final groupController = Get.find<GroupController>();
                                  final group = groupController.groups
                                      .where((g) => g.groupId == userOrGroupId)
                                      .firstOrNull;

                                  if (group != null) {
                                    // ✅ Safely handle nullable list
                                    final List<String> visibleUserIds = mainScreenKey.currentState?.visibleUserIds ?? [];
                                final currentUserId = AuthController.instance.currentUser!.userId;

                                // ✅ Filter recipients
                                final recipients = group.participants.where((member) {
                                  // Always skip sender
                                  if (member.userId == currentUserId) return false;

                                  // If group == 'abc', only send to visible users EXCEPT current user
                                  if (group.groupId == '1e8bf062-772f-42b3-9a09-7f0021f936db') {
                                    return visibleUserIds.contains(member.userId) &&
                                          member.userId != currentUserId;
                                  }

                                  // For all other groups, send to everyone except sender
                                  return true;
                                }).toList();


                                    for (final member in recipients) {
                                      final user = await UserApi.getUser(member.userId);
                                      if (user?.deviceToken != null) {
                                        await PushNotificationService.sendNotification(
                                          type: NotificationType.message,
                                          title: group.name,
                                          body: 'Group Msg',
                                          deviceToken: member.deviceToken,
                                          chatId: group.groupId,                                
                                        );
                                      }
                                    }
                                  }
                                }

                                   WebSocketPTTController()
                                      .joinGroup(userOrGroupId);
                                  await WebSocketPTTController().startRecording();
                                  // await AgoraController().toggleMic(false);
                                  // await AgoraController()
                                  //     .engine!
                                  //     .enableLocalAudio(true);

                                  if (await Vibration.hasVibrator() ?? false) {
                                    if (await Vibration.hasAmplitudeControl() ??
                                        false) {
                                      Vibration.vibrate(
                                          duration: 50, amplitude: 128);
                                    } else {
                                      Vibration.vibrate(duration: 50);
                                    }
                                  }
                                },
                              onPointerUp: () async {
                              bool hasAccess = await customBottomSection.currentState!.isSubscribed();
                              if (!hasAccess){
                            // ✅ Check daily limit / subscription inside handleLimitedButtonPress
                            print("Checking PTT button limit/subscription...");
                            final allowed = await mainScreenKey.currentState!
                                .handleLimitedButtonPress(context: context, buttonId: 'PTT');

                            if (!allowed) {
                              print("Button press blocked: limit or subscription restriction");
                              return; // stop if limit or subscription not allowed
                            }
                                  }

                                  await WebSocketPTTController().stopRecording();
                                  await WebSocketPTTController().sendAudio();
                                  
                                   WebSocketPTTController()
                                      .joinGroup(myid.toString());
                                  // await AgoraController().toggleMic(true);
                                  // await AgoraController()
                                  //     .engine!
                                  //     .enableLocalAudio(false);


                                    if (isGroup) {
                                  final groupController = Get.find<GroupController>();
                                  final group = groupController.groups
                                      .where((g) => g.groupId == userOrGroupId)
                                      .firstOrNull;

                                  if (group != null) {
                                    // ✅ Safely handle nullable list
                                    final List<String> visibleUserIds = mainScreenKey.currentState?.visibleUserIds ?? [];
                                final currentUserId = AuthController.instance.currentUser!.userId;

                                // ✅ Filter recipients
                                final recipients = group.participants.where((member) {
                                  // Always skip sender
                                  if (member.userId == currentUserId) return false;

                                  // If group == 'abc', only send to visible users EXCEPT current user
                                  if (group.groupId == '1e8bf062-772f-42b3-9a09-7f0021f936db') {
                                    return visibleUserIds.contains(member.userId) &&
                                          member.userId != currentUserId;
                                  }

                                  // For all other groups, send to everyone except sender
                                  return true;
                                }).toList();


                                    for (final member in recipients) {
                                      final user = await UserApi.getUser(member.userId);
                                      if (user?.deviceToken != null) {
                                        await PushNotificationService.sendNotification(
                                          type: NotificationType.message,
                                          title: group.name,
                                          body: 'Group PTT Ends',
                                          deviceToken: member.deviceToken,
                                           data: {
                                             'chatId': group.groupId, // ✅ this must be passed
                                              'isGroup': true,
                                          },
                                        );
                                      }
                                    }
                                  }
                                }
                                else{
                                        final User? Pttcaller =
                                      await UserApi.getUser(userOrGroupId);
                                  // await PushNotificationService
                                  //     .sendNotification(
                                  //   type: NotificationType.message,
                                  //   title: Pttcaller!.fullname,
                                  //   body: 'Completed PTT',
                                  //   deviceToken: Pttcaller.deviceToken,
                                  //   data: {
                                  //     'action': 'disable',
                                  //   },
                                  // );
                                }
                                  controller.sendMessage(
                                    MessageType.text,
                                    text: "I just sent a PTT",
                                    isRecAudio: false,
                                  ); 
                                  

                                  Get.snackbar(
                                    "Notification Sent!",
                                    "PTT Sent Success!",
                                    snackPosition: SnackPosition.TOP,
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: const Color.fromARGB(
                                        255, 41, 164, 246),
                                    colorText: Colors.white,
                                  );
                              },
                            ),
                          )
                        : const SizedBox.shrink(),
                  ],
                ),
              );
            },
          ),
        ),
        // Show scroll list button
        floatingActionButton: _buildScrollButton,
      );
    },
  );
}

  Widget _buildMessagesList(String? wallpaperPath) {
    // Get messages controller instance
    final MessageController controller = Get.find();
    // Get selected group instance
    Group? group = controller.selectedGroup;

    return Obx(
      () {
        // Check error
        if (controller.isLoading.value) {
          return const Center(child: LoadingIndicator(size: 35));
        } else if (controller.messages.isEmpty) {
          return NoData(
            iconData: IconlyBold.chat,
            text: 'no_messges'.tr,
            textColor: wallpaperPath != null ? Colors.white : null,
          );
        } else {
          // Get Messages List in reversed order
          final List<Message> messages = controller.messages;

          return ListView.builder(
            reverse: true,
            shrinkWrap: true,
            cacheExtent: double.maxFinite,
            controller: controller.scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              // Get Message Object
              final Message message = messages[index];

              // Check unread message to update it
              if (!isGroup) {
                if (!message.isSender && !message.isRead) {
                  MessageApi.readMsgReceipt(
                    messageId: message.msgId,
                    receiverId: user!.userId,
                  );
                }
              }

              // <--- Handle group date --->
              final DateTime? sentAt = message.sentAt;
              Widget dateSeparator = const SizedBox.shrink();

              // Check sent time
              if (sentAt != null) {
                // Check first element in reverse order
                if (index == messages.length - 1) {
                  dateSeparator = GroupDateSeparator(sentAt.formatDateTime);
                } else
                // Validate the index in range
                if (index + 1 < messages.length) {
                  // Get previous date in reverse order
                  DateTime prevDate = messages[index + 1].sentAt!;
                  // Check different dates
                  if (!(sentAt.isSameDate(prevDate))) {
                    dateSeparator = GroupDateSeparator(
                      sentAt.formatDateTime,
                    );
                  }
                }
              }

              // Get sender user
              final User senderUser =
                  isGroup ? group!.getMemberProfile(message.senderId) : user!;

              final Rxn<Message> selectedMessage = controller.selectedMessage;
              final bool isSelected = selectedMessage.value == message;
              final EdgeInsets? bubblePadding =
                  isSelected ? const EdgeInsets.fromLTRB(16, 0, 16, 16) : null;
              final Color? bubbleColor =
                  isSelected ? primaryColor.withOpacity(0.3) : null;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Show Group Date time
                  dateSeparator,
                  // Show encrypted notice
                  if (!isGroup && index == messages.length - 1)
                    const EncryptedNotice(),
                  // Bubble message
                  GestureDetector(
                    onLongPress: () {
                      if (message.type == MessageType.groupUpdate) {
                        return;
                      }
                      selectedMessage.value = message;
                    },
                    onTap: () => selectedMessage.value = null,
                    child: Container(
                      padding: bubblePadding,
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: isSelected ? borderRadius : null,
                      ),
                      child: isGroup && message.type == MessageType.groupUpdate
                          ? UpdateMessage(
                              group: group!,
                              message: message,
                            )
                          : BubbleMessage(
                              message: message,
                              user: user,
                              group: group,
                              onTapProfile: message.isSender
                                  ? null
                                  : () => RoutesHelper.toProfileView(
                                      senderUser, isGroup),
                              onReplyMessage: message.isDeleted
                                  ? null
                                  : () => controller.replyToMessage(message),
                            ),
                    ),
                  ),
                ],
              );
            },
          );
        }
      },
    );
  }

  Widget? get _buildScrollButton {
    // Get messages controller instance
    final MessageController controller = Get.find();
    return Obx(() {
      // Check it.
      if (!controller.showScrollButton.value) {
        return const SizedBox.shrink();
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -10,
            bottom: 50,
            child: ScrollDownButton(
              onPress: () => controller.scrollToBottom(),
            ),
          ),
        ],
      );
    });
  }
}


class PushToTalkMicButton extends StatefulWidget {
  final VoidCallback onPointerDown;
  final VoidCallback onPointerUp;

  const PushToTalkMicButton({
    required this.onPointerDown,
    required this.onPointerUp,
    super.key,
  });

  @override
  State<PushToTalkMicButton> createState() => _PushToTalkMicButtonState();
}

class _PushToTalkMicButtonState extends State<PushToTalkMicButton> {
  double _scale = 1.0;

  final AudioPlayer _audioPlayer = AudioPlayer();
  
  
  void _zoomIn() {
    setState(() {
      _scale = 1.5;
    });
  }

  void _zoomOut() {
    setState(() {
      _scale = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) async {
        _zoomIn();
        
        widget.onPointerDown();
      },
      onPointerUp: (_) async {
        _zoomOut();
        widget.onPointerUp();
      },
      child: Center(
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          child: Container(
            width: 55, 
            height: 55,
            padding: const EdgeInsets.only(right: 5),
            child: Image.asset(
              'assets/maris/ptta.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  
}