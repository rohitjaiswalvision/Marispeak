import 'package:flutter/material.dart';
import 'package:marispeaks/api/user_api.dart';
import 'package:marispeaks/components/message_badge.dart';
import 'package:marispeaks/controllers/auth_controller.dart';
import 'package:marispeaks/helpers/routes_helper.dart';
import 'package:get/get.dart';
import 'package:marispeaks/models/chat.dart';
import 'package:marispeaks/models/user.dart';
import 'package:marispeaks/components/badge_count.dart';
import 'package:marispeaks/components/cached_circle_avatar.dart';
import 'package:marispeaks/components/sent_time.dart';
import 'package:marispeaks/theme/app_theme.dart';
import 'package:marispeaks/config/theme_config.dart';

// ignore: must_be_immutable
class ChatCard extends StatelessWidget {
  ChatCard(
    this.chat, {
    super.key,
      required this.onDeleteChat,
    this.isForPTT = false,        // <-- NEW
    this.onSelectUser,            // <-- NEW
    this.onTap, // ✅ add this line

  });

  final Function()? onTap; // ✅ add this line
  final bool isForPTT;
  final Function(User)? onSelectUser;
  final Chat chat;
  User? updatedUser;
  final Function()? onDeleteChat;

  @override
  Widget build(BuildContext context) {
    // Vars
    final bool isDarkMode = AppTheme.of(context).isDarkMode;
    final User user = chat.receiver!;

    return InkWell(
     onTap: () async {
  final receiver = updatedUser ?? user;

  if (isForPTT && onSelectUser != null) {
    onSelectUser!(receiver); // ← SELECT receiver only
  } else if (onTap != null) {
    onTap!(); // ← CUSTOM behavior
  } else {
    RoutesHelper.toMessages(user: receiver);
    chat.viewChat(); // ← Default: open chat
  }
},

      child: Container(
        padding: const EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDarkMode ? greyLight.withOpacity(0.10) : greyLight,
            ),
          ),
        ),
        child: StreamBuilder<User>(
          stream: UserApi.getUserUpdates(user.userId),
          builder: (context, snapshot) {
            updatedUser = snapshot.data;
            final User receiver = updatedUser ?? user;

            return GestureDetector(
              onLongPress: onDeleteChat,
              child: Row(
                children: [
                  // Profile avatar
                  CachedCircleAvatar(
                    imageUrl: receiver.photoUrl,
                    radius: 28,
                    isOnline: receiver.isOnline,
                    borderColor: chat.unread > 0 ? primaryColor : null,
                  ),
                  const SizedBox(width: 10),
                  // Profile info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 01 - name & sent time
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Profile name
                            Text(
                              receiver.fullname,
                              style: Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Sent time
                            SentTime(
                              time:
                                  chat.isDeleted ? chat.updatedAt : chat.sentAt,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),

                        // Row 02 - Last message & unread
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Last message
                            LastMessage(chat: chat, user: receiver),
                            // Show muted icon
                            if (chat.isMuted)
                              const Icon(
                                Icons.volume_off,
                                color: greyColor,
                              ),
                            // Total unread messages
                            BadgeCount(
                              counter: chat.unread,
                              bgColor: const Color(0xFFfa4e1c),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class LastMessage extends StatelessWidget {
  const LastMessage({
    super.key,
    required this.chat,
    required this.user,
  });

  final Chat chat;
  final User user;

  @override
  Widget build(BuildContext context) {
    // Get text style
    final TextStyle style =
        Theme.of(context).textTheme.bodyMedium!.copyWith(color: primaryColor);
    // Get current user ID.
    final String currentUserId = AuthController.instance.currentUser!.userId;

    final bool isTyping = user.isTyping && user.typingTo == currentUserId;
    final bool isRecording =
        user.isRecording && user.recordingTo == currentUserId;

    // Check chat status
    if (chat.isDeleted) {
      return MessageDeleted(
        iconSize: 22,
        isSender: chat.isSender,
      );
    } else if (isTyping) {
      return Text('typing'.tr, style: style);
    } else if (isRecording) {
      return Text('recording_audio'.tr, style: style);
    }
    return Expanded(
      child: MessageBadge(
        type: chat.msgType,
        textMsg: chat.lastMsg,
        maxLines: 1,
        textStyle: const TextStyle(fontSize: 16, color: greyColor),
      ),
    );
  }
}
