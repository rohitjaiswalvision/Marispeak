import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:marispeaks/components/badge_count.dart';
import 'package:marispeaks/components/message_badge.dart';
import 'package:marispeaks/components/svg_icon.dart';
import 'package:marispeaks/controllers/auth_controller.dart';
import 'package:marispeaks/models/group.dart';
import 'package:marispeaks/models/user.dart';
import 'package:marispeaks/models/message.dart';
import 'package:marispeaks/components/cached_circle_avatar.dart';
import 'package:marispeaks/components/sent_time.dart';
import 'package:marispeaks/theme/app_theme.dart';
import 'package:marispeaks/config/theme_config.dart';
import 'update_message.dart';

class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.group,
    this.onPress,
  });

  final Group group;
  final Function()? onPress;

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = AppTheme.of(context).isDarkMode;

    return InkWell(
      onTap: onPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDarkMode ? greyLight.withOpacity(0.10) : greyLight,
            ),
          ),
        ),
        child: Row(
          children: [
            _buildPhoto,
            const SizedBox(width: 10),
            Expanded(
              child: Obx(() {
                final Message? lastMsg = group.lastMsg;
                final String senderId = lastMsg?.senderId ?? '';
                final User senderMember = group.getMemberProfile(senderId);
                final bool isSender =
                    AuthController.instance.currentUser!.userId == senderId;
                final bool isDeleted =
                    lastMsg != null && lastMsg.isDeleted;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 01 — Name & Time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SentTime(time: lastMsg?.sentAt),
                      ],
                    ),
                    const SizedBox(height: 2),

                    // Row 02 — Sender, Message, Icons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (lastMsg != null &&
                            !isDeleted &&
                            lastMsg.type != MessageType.groupUpdate)
                          Text(
                            isSender
                                ? "${'you'.tr}: "
                                : "~ ${senderMember.fullname}: ",
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        Expanded(child: _buildLastMessage(context, lastMsg)),
                        if (group.isMuted)
                          const Icon(Icons.volume_off, color: greyColor),
                        BadgeCount(
                          counter: group.unread,
                          bgColor: const Color(0xFFfa4e1c),
                        ),
                      ],
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget get _buildPhoto {
    const Widget broadcastIcon = SvgIcon(
      'assets/icons/broadcast.svg',
      width: 32,
      height: 32,
      color: Colors.white,
    );

    if (group.isBroadcast && group.photoUrl.isEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundColor: Colors.grey[350],
        child: broadcastIcon,
      );
    }

    return CachedCircleAvatar(
      imageUrl: group.photoUrl,
      radius: 28,
      isGroup: true,
    );
  }

  Widget _buildLastMessage(BuildContext context, Message? lastMsg) {
    if (lastMsg == null) {
      return Text(
        '${group.participants.length} ${group.isBroadcast ? 'recipients'.tr : 'participants'.tr}',
        overflow: TextOverflow.ellipsis,
      );
    } else if (lastMsg.type == MessageType.groupUpdate) {
      return UpdateMessage(
        group: group,
        message: lastMsg,
        isTextFormat: true,
      );
    } else if (lastMsg.isDeleted) {
      return MessageDeleted(
        iconSize: 22,
        isSender: lastMsg.isSender,
      );
    }

    return MessageBadge(
      type: lastMsg.type,
      textMsg: lastMsg.textMsg,
      maxLines: 1,
    );
  }
}
