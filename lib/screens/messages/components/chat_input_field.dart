import 'dart:async';
import 'dart:io';

import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:marispeaks/components/svg_icon.dart';
import 'package:marispeaks/config/theme_config.dart';
import 'package:marispeaks/controllers/auth_controller.dart';
import 'package:marispeaks/helpers/dialog_helper.dart';
import 'package:marispeaks/models/group.dart';
import 'package:marispeaks/models/location.dart';
import 'package:marispeaks/models/message.dart';
import 'package:marispeaks/models/user.dart';
import 'package:marispeaks/screens/home/MainScreenUI.dart';
import 'package:marispeaks/screens/messages/components/emoji_media.dart';
import 'package:marispeaks/screens/messages/components/reply_message.dart';
import 'package:marispeaks/screens/messages/controllers/message_controller.dart';
import 'package:marispeaks/media/helpers/media_helper.dart';
import 'package:flutter/material.dart';
import 'package:marispeaks/theme/app_theme.dart';
import 'package:get/get.dart';
import '../controllers/block_controller.dart';
import 'attachment/attachment_menu.dart';

class ChatInputField extends StatefulWidget {
  const ChatInputField({
    super.key,
    this.user,
    this.group,
  });

  final User? user;
  final Group? group;

  @override
  ChatInputFieldState createState() => ChatInputFieldState();
}

class ChatInputFieldState extends State<ChatInputField> {
  // Get Controllers
  final MessageController controller = Get.find();
  final BlockController blockCrl = Get.find();

@override
Widget build(BuildContext context) {
  final bool isDarkMode = AppTheme.of(context).isDarkMode;
  final bool isIOS = Platform.isIOS;
  final String currentUserId = AuthController.instance.currentUser!.userId;

  return Obx(
    () {
      String senderName = '';
      if (widget.group != null) {
        final Message? message = controller.replyMessage.value;
        if (message != null) {
          final member = widget.group!.getMemberProfile(message.senderId);
          senderName = member.fullname;
        }
      } else {
        senderName = widget.user!.fullname;
      }

      final bool isGroup = widget.group != null;
      final TextStyle style =
          Theme.of(context).textTheme.bodyLarge!.copyWith(color: errorColor);
      final Radius replyBorderRadius = controller.isReplying
          ? const Radius.circular(16)
          : const Radius.circular(30);

      final bool isUserBlocked = blockCrl.isUserBlocked.value;
      final bool isCurrentUserBlocked = blockCrl.isCurrentUserBlocked.value;

      // Check 1-to-1 blocked status
      if (!isGroup && isUserBlocked || isCurrentUserBlocked) {
        return _blockedMessage(
            isUserBlocked: isUserBlocked,
            isCurrentUserBlocked: isCurrentUserBlocked);
      }

      // Check removed member status
      if (isGroup && widget.group!.isRemoved(currentUserId)) {
        return Container(
          padding: const EdgeInsets.all(defaultPadding / 2),
          child: Text('not_participant_message'.tr,
              textAlign: TextAlign.center, style: style),
        );
      }

      final bool isAdmin = widget.group?.isAdmin(currentUserId) ?? false;

      // Check Admin messages
      if (!isAdmin) {
        if (isGroup && !widget.group!.sendMessages) {
          return Container(
            padding: const EdgeInsets.all(defaultPadding / 2),
            child: Text('only_admins_can_send_messages'.tr,
                textAlign: TextAlign.center, style: style),
          );
        }
      }

      return PopScope(
        canPop: !controller.showEmoji.value,
        onPopInvokedWithResult: (bool value, _) {
          if (value) return;

          if (controller.showEmoji.value) {
            controller.showEmoji.value = false;
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ///
            /// ✅ Show quick chips ONLY if groupId == "abc"
            ///
            if (isGroup && widget.group!.groupId == "1e8bf062-772f-42b3-9a09-7f0021f936db")
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  children: [
                    _quickChip("Flat Battery"),
                    _quickChip("Fuel Needed"),
                    _quickChip("Tow Needed"),
                    _quickChip("Other Help"),
                  ],
                ),
              ),

            // <--- Chat Input --->
            Padding(
              padding: EdgeInsets.only(
                  left: 8, top: 8, right: 8, bottom: isIOS ? 25 : 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: isDarkMode ? null : greyLight,
                        borderRadius: BorderRadius.only(
                          topLeft: replyBorderRadius,
                          topRight: replyBorderRadius,
                          bottomLeft: const Radius.circular(30),
                          bottomRight: const Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (controller.replyMessage.value != null)
                            ReplyMessage(
                              cancelReply: () => controller.cancelReply(),
                              message: controller.replyMessage.value!,
                              senderName: senderName,
                            ),
                          TextFormField(
                            focusNode: controller.chatFocusNode,
                            controller: controller.textController,
                            minLines: 1,
                            maxLines: 4,
                            onTap: () => controller.showEmoji.value = false,
                            onChanged: (String text) {
                              final hasText = text.trim().isNotEmpty;
                              controller.isTextMsg.value = hasText;
                              if (hasText) {
                                mainScreenKey.currentState?.hideMic();
                              } else {
                                mainScreenKey.currentState?.showMic();
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'message'.tr,
                              filled: true,
                              fillColor: isDarkMode ? null : greyLight,
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              border: const OutlineInputBorder(
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(16),
                                child: GestureDetector(
                                  onTap: () {
                                    _showAttachmentMenu();
                                    controller.scrollToBottom();
                                    controller.chatFocusNode.unfocus();
                                    controller.showEmoji.value = false;
                                  },
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              suffixIcon: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () =>
                                          controller.handleEmojiPicker(),
                                      child: SvgIcon(
                                        controller.showEmoji.value
                                            ? 'assets/icons/keyboard.svg'
                                            : 'assets/icons/emoji_very_happy.svg',
                                        color: isDarkMode
                                            ? Colors.white54
                                            : Colors.black54,
                                        width: 30,
                                        height: 30,
                                      ),
                                    ),
                                    if (!controller.isTextMsg.value)
                                      GestureDetector(
                                        onTap: () async {
                                          final String? gifUrl =
                                              await MediaHelper.getGif(context);
                                          if (gifUrl == null) return;
                                          await controller.sendMessage(
                                            MessageType.gif,
                                            gifUrl: gifUrl,
                                          );
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 15),
                                          child: Icon(
                                            Icons.gif_box,
                                            size: 30,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    if (!controller.isTextMsg.value)
                                      GestureDetector(
                                        onTap: () async {
                                          controller.scrollToBottom();
                                          controller.chatFocusNode.unfocus();
                                          controller.showEmoji.value = false;

                                          final File? file =
                                              await MediaHelper.openCameraScreen(
                                                  context);
                                          if (file == null) return;

                                          if (MediaHelper.isImage(file.path)) {
                                            await controller.sendMessage(
                                                MessageType.image,
                                                file: file);
                                            return;
                                          }

                                          if (MediaHelper.isVideo(file.path)) {
                                            await controller.sendMessage(
                                                MessageType.video,
                                                file: file);
                                            return;
                                          }
                                        },
                                        child: const Icon(
                                          IconlyBold.camera,
                                          size: 30,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      if (controller.isTextMsg.value) {
                        final String text = controller.textController.text;
                        if (text.trim().isEmpty) return;
                        controller.sendMessage(MessageType.text, text: text);
                      } else {
                        final File? audio =
                            await DialogHelper.showAudioRecorderModal(
                          widget.user?.userId,
                        );
                        if (audio != null) {
                          controller.sendMessage(
                            MessageType.audio,
                            file: audio,
                            isRecAudio: true,
                          );
                        }
                      }
                    },
                    icon: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(8),
                      decoration: controller.isTextMsg.value
                          ? const BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                            )
                          : null,
                      child: controller.isTextMsg.value
                          ? const SvgIcon(
                              'assets/icons/send.svg',
                              color: Colors.white,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
            Offstage(
              offstage: !controller.showEmoji.value,
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.35,
                child: EmojiMedia(
                  textController: controller.textController,
                  onSelected: (_, __) {
                    controller.isTextMsg.value = true;
                  },
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Helper widget for quick chips
Widget _quickChip(String label) {
  return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ActionChip(
      label: Text(label),
      onPressed: () {
        controller.sendMessage(MessageType.text, text: label);
      },
    ),
  );
}

  // Handle Attachment Menu
  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AttachmentMenu(
        sendDocs: (List<File>? files) async {
          if (files == null) return;
          // Hold futures
          List<Future> futures = [];

          // Handle docs...
          for (File file in files) {
            // Get file path
            final String path = file.path;

            // Check comomn file types
            if (MediaHelper.isImage(path)) {
              // Send image file
              futures.add(
                controller.sendMessage(MessageType.image, file: file),
              );
              //
            } else if (MediaHelper.isAudio(path)) {
              // Send audio file
              futures.add(
                controller.sendMessage(MessageType.audio, file: file),
              );
            } else if (MediaHelper.isVideo(path)) {
              // Send video file
              futures.add(
                controller.sendMessage(MessageType.video, file: file),
              );
              //
            } else {
              // Send this file as document
              futures.add(controller.sendMessage(MessageType.doc, file: file));
            }
          }

          // Send all the files once
          await Future.wait(futures);
        },
        sendImage: (File? file) {
          if (file == null) return;
          // Send image message
          controller.sendMessage(MessageType.image, file: file);
        },
        sendVideo: (File? file) {
          // Send video message
          controller.sendMessage(MessageType.video, file: file);
        },
        sendLocation: (Location? location) {
          // Send location message
          controller.sendMessage(MessageType.location, location: location);
        },
      ),
    );
  }

  Widget _blockedMessage({
    required bool isUserBlocked,
    required bool isCurrentUserBlocked,
  }) {
    String message = '';

    if (isUserBlocked) {
      message = 'you_have_blocked_use_tap_the_top_corner_options_to_unblock';
    } else if (isCurrentUserBlocked) {
      message = 'user_has_blocked_you_it_s_not_possible_to_send_messages';
    }

    return Container(
      padding: const EdgeInsets.all(defaultPadding / 2),
      child: Text(
        message.trParams({'firstName': widget.user?.fullname ?? ''}),
        textAlign: TextAlign.center,
        style:
            Theme.of(context).textTheme.bodyLarge!.copyWith(color: errorColor),
      ),
    );
  }
}
