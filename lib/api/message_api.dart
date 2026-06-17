  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:flutter/material.dart';
  import 'package:marispeaks/api/group_api.dart';
  import 'package:marispeaks/helpers/app_helper.dart';
  import 'package:marispeaks/helpers/dialog_helper.dart';
  import 'package:marispeaks/models/group.dart';
import 'package:marispeaks/screens/home/MainScreenUI.dart';
  import 'package:marispeaks/screens/messages/controllers/message_controller.dart';
  import 'package:marispeaks/tabs/chats/controllers/chat_controller.dart';
  import 'package:get/get.dart';
  import 'package:marispeaks/api/chat_api.dart';
  import 'package:marispeaks/controllers/auth_controller.dart';
  import 'package:marispeaks/models/chat.dart';
  import 'package:marispeaks/models/message.dart';
  import 'package:marispeaks/models/user.dart';
  import 'package:marispeaks/services/push_notification_service.dart';

  abstract class MessageApi {
    //
    // MessageApi - CRUD Operations
    //

    // Firestore instance
    static final _firestore = FirebaseFirestore.instance;
    static final _setOptions = SetOptions(merge: true);

    // Get Messages collection reference
    static CollectionReference<Map<String, dynamic>> _getCollectionRef({
      required userId1,
      required userId2,
    }) {
      return _firestore.collection('Users/$userId1/Chats/$userId2/Messages');
    }

  // 1-to-1 message
  static Future<void> sendMessage({
    required Message message,
    required User receiver,
  }) async {
    try {
      final User currentUser = AuthController.instance.currentUser!;

      // Save for current user
      _getCollectionRef(userId1: currentUser.userId, userId2: receiver.userId)
          .doc(message.msgId)
          .set(message.toMap(isGroup: false));

      // Save for receiver
      _getCollectionRef(userId1: receiver.userId, userId2: currentUser.userId)
          .doc(message.msgId)
          .set(message.toMap(isGroup: false));

      // Save last chat
      ChatApi.saveChat(
        userId1: currentUser.userId,
        userId2: receiver.userId,
        message: message,
       // visibleUserIds: mainScreenKey.currentState?.visibleUserIds ?? [],
      );

      // Send push notification (standardized)
      await PushNotificationService.sendNotification(
        type: NotificationType.message,
        title: currentUser.fullname,
        body: PushNotificationService.getMessageType(message.type),
        deviceToken: receiver.deviceToken,
        data: {
          'type': 'chat',
          'isGroup': false,
          'userId': receiver.userId,
          'groupId': null,
          'senderId': currentUser.userId,
          'chatId': message.msgId,
        },
      );

      debugPrint('sendMessage() -> success');
    } catch (e) {
      debugPrint('sendMessage() -> error: $e');
    }
  }


static Future<void> forwardMessage({
  required Message message,
  required List contacts,
}) async {
  try {
    final User currentUser = AuthController.instance.currentUser!;

    // Separate users and groups
    final List<User> users = contacts.whereType<User>().toList();
    final List<Group> groups = contacts.whereType<Group>().toList();

    // Update message for forwarding
    message.isForwarded = true;
    message.senderId = currentUser.userId;
    message.msgId = AppHelper.generateID;

    // Forward to users
    List<Future> usersMsgFutures = users.map<Future>((user) {
      return sendMessage(message: message, receiver: user);
    }).toList();

    
// Forward to groups
List<Future> groupsMsgFutures = groups.map<Future>((group) {
  return sendGroupMessage(
    group: group,
    message: message,
    visibleUserIds: mainScreenKey.currentState?.visibleUserIds ?? [],
  );
}).toList();

    // Execute all notifications
    await Future.wait([...usersMsgFutures, ...groupsMsgFutures]);

    DialogHelper.showSnackbarMessage(
      SnackMsgType.success,
      'message_forwarded_successfully'.tr,
    );
  } catch (e) {
    DialogHelper.showSnackbarMessage(SnackMsgType.error, e.toString());
  }
}


static Future<void> updateUnreadList(Group group, {List<String>? visibleUserIds}) async {
  Map<String, dynamic> updates = {};

  final bool isTargetGroup = group.groupId == "1e8bf062-772f-42b3-9a09-7f0021f936db";

  for (final member in group.members) {
    // Only update unread count if member should see the message
    if (!isTargetGroup || (visibleUserIds != null && visibleUserIds.contains(member.userId))) {
      updates['unreadList.${member.userId}'] = FieldValue.increment(1);
    }
  }

  if (updates.isNotEmpty) {
    await GroupApi.groupsRef.doc(group.groupId).update(updates);
  }
}


static Future<void> saveGroupMessage(
  Group group, {
  Map<String, dynamic>? messageData,
}) async {
  try {
    final seenBy = messageData?['seenBy'] as List<String>? ?? [];

    // ✅ Update chat previews only for users in seenBy
    for (var userId in seenBy) {
      await FirebaseFirestore.instance
          .collection('Users/$userId/Chats')
          .doc(group.groupId)
          .set({
            'lastMsg': group.lastMsg!.textMsg,
            'msgId': group.lastMsg!.msgId,
            'sentAt': group.lastMsg!.sentAt,
            'unread': FieldValue.increment(1),
            'isGroup': true,
          }, SetOptions(merge: true));
    }

    // ✅ Merge seenBy + base message together before saving
    final finalMessageData = {
      ...group.lastMsg!.toMap(isGroup: true),
      if (messageData != null) ...messageData,
    };

    await Future.wait([
      // ✅ Update group info correctly
      GroupApi.groupsRef
          .doc(group.groupId)
          .update(messageData ?? group.toUpdateMap()),

      // ✅ Save the group message with merged data
      GroupApi.groupsRef
          .doc(group.groupId)
          .collection('Messages')
          .doc(group.lastMsg!.msgId)
          .set(finalMessageData, SetOptions(merge: true)),
    ]);

    debugPrint('saveGroupMessage() -> success');
  } catch (e) {
    debugPrint('saveGroupMessage() -> error: $e');
  }
} 


// Send group message
static Future<void> sendGroupMessage({
  required Group group,
  required Message message,
  required List<String> visibleUserIds, // pass your global visible users
}) async {
  try {
    final User sender = group.getMemberProfile(message.senderId);
    group.lastMsg = message;

    // Prepare message-level data
    final bool isTargetGroup = group.groupId == "1e8bf062-772f-42b3-9a09-7f0021f936db";
    final Map<String, dynamic>? messageData = isTargetGroup
        ? {'seenBy': visibleUserIds} // ✅ Only for abc group
        : null;

    // Save message with seenBy inside message
    await saveGroupMessage(group, messageData: messageData);

    // Send notifications
    List<Future<void>> notifyFutures = [];

    for (final member in group.participants) {
      final bool shouldSend = member.userId != message.senderId &&
          !member.mutedGroups.contains(group.groupId) &&
          (!isTargetGroup || visibleUserIds.contains(member.userId));

      if (shouldSend) {
        debugPrint('[MessageApi] Sending group message -> ${group.groupId}');

        notifyFutures.add(
          PushNotificationService.sendNotification(
            type: NotificationType.group,
            title: group.name,
            body: "${sender.fullname}: ${PushNotificationService.getMessageType(message.type)}",
            deviceToken: member.deviceToken,
            data: {
              'type': 'chat',
              'isGroup': true,
              'groupId': group.groupId,
              'userId': null,
              'senderId': sender.userId,
              'msgId': message.msgId,
              'seenBy': isTargetGroup ? visibleUserIds : null,
            },
          ),
        );
      }
    }

    await Future.wait(notifyFutures);
    debugPrint('sendGroupMessage() -> success');
  } catch (e) {
    debugPrint('sendGroupMessage() -> error: $e');
  }
}

static Future<void> sendBroadcastMessage({
  required Group group,
  required Message message,
}) async {
  try {
    // Update last message
    group.lastMsg = message;
    await saveGroupMessage(group);

    // Send message to each recipient individually
    List<Future> messageFutures = group.recipients.map<Future>((receiver) {
      // Reuse sendMessage so payload is standardized
      return sendMessage(message: message, receiver: receiver);
    }).toList();

    await Future.wait(messageFutures);

    debugPrint('sendBroadcastMessage() -> success');
  } catch (e) {
    debugPrint('sendBroadcastMessage() -> error: $e');
  }
}


    // Save missed call message for receiver
  // Missed call
  static Future<void> sendMissedCallMessage({
    required bool isVideo,
    required User receiver,
  }) async {
    try {
      final User currentUser = AuthController.instance.currentUser!;
      final String body =
          isVideo ? 'you_missed_a_video_call'.tr : 'you_missed_a_voice_call'.tr;

      final Message message = Message(
        msgId: AppHelper.generateID,
        senderId: currentUser.userId,
        type: MessageType.text,
        textMsg: body,
      );

      final Chat chat = Chat(
        senderId: currentUser.userId,
        msgType: message.type,
        lastMsg: message.textMsg,
        msgId: message.msgId,
      );

      await Future.wait([
        // Save last chat
        _firestore
            .collection('Users/${receiver.userId}/Chats')
            .doc(currentUser.userId)
            .set(chat.toMap(true), _setOptions),

        // Save message
        _getCollectionRef(userId1: receiver.userId, userId2: currentUser.userId)
            .doc(message.msgId)
            .set(message.toMap(isGroup: false)),

        // Push notification
        PushNotificationService.sendNotification(
          type: NotificationType.message,
          title: currentUser.fullname,
          body: body,
          deviceToken: receiver.deviceToken,
          data: {
            'type': 'missed_call',
            'isGroup': false,
            'userId': receiver.userId,
            'groupId': null,
            'senderId': currentUser.userId,
            'chatId': message.msgId,
          },
        ),
      ]);

      debugPrint('sendMissedCallMessage() -> success');
    } catch (e) {
      debugPrint('sendMissedCallMessage() -> error: $e');
    }
  }
  
    // Get 1-to-1 messages
    static Stream<List<Message>> getMessages(String userId) {
      // Get current user
      final User currentUser = AuthController.instance.currentUser!;

      // Query messages
      return _getCollectionRef(userId1: currentUser.userId, userId2: userId)
          .orderBy('sentAt', descending: true)
          .snapshots()
          .map((event) {
        return event.docs.map((doc) {
          return Message.fromMap(
              data: doc.data(), docRef: doc.reference, isGroup: false);
        }).toList();
      });
    }

static Stream<List<Message>> getGroupMessages(String groupId, String currentUserId) {
  return GroupApi.groupsRef
      .doc(groupId)
      .collection('Messages')
      .orderBy('sentAt', descending: true)
      .snapshots()
      .map((event) {
    return event.docs
        .where((doc) {
          final data = doc.data();
          // Only include messages where seenBy contains current user
          final seenBy = List<String>.from(data['seenBy'] ?? []);
          return groupId != "1e8bf062-772f-42b3-9a09-7f0021f936db" || seenBy.contains(currentUserId);
        })
        .map((doc) => Message.fromMap(
              data: doc.data(),
              docRef: doc.reference,
              isGroup: true,
            ))
        .toList();
  });
}

    // Read message receipt
    static Future<void> readMsgReceipt({
      required String receiverId,
      required String messageId,
    }) async {
      try {
        final User currentUser = AuthController.instance.currentUser!;

        await _getCollectionRef(userId1: receiverId, userId2: currentUser.userId)
            .doc(messageId)
            .update({'isRead': true});
        debugPrint('readMsgReceipt() -> success');
      } catch (e) {
        debugPrint('readMsgReceipt() -> error: $e');
      }
    }

    // Delete message for me: 1-to-1 chat
    static Future<void> deleteMsgForMe({
      required Message message,
      required String receiverId,
      required Message? replaceMsg,
    }) async {
      try {
        final User currentUser = AuthController.instance.currentUser!;

        // Get the Chat node
        final Chat chat = ChatController.instance.getChat(receiverId);

        // Check the last message id to update the current user chat node
        if (chat.msgId == message.msgId) {
          ChatApi.softDeleteChat(
            userId1: currentUser.userId,
            userId2: receiverId,
            msgId: message.msgId,
          );
        }

        // Soft delete message for me
        await _getCollectionRef(userId1: currentUser.userId, userId2: receiverId)
            .doc(message.msgId)
            .set(message.toDeletedMap(), _setOptions);
        // Show feedback
        DialogHelper.showSnackbarMessage(
            SnackMsgType.success, 'message_deleted_successfully'.tr);
      } catch (e) {
        DialogHelper.showSnackbarMessage(SnackMsgType.error, e.toString());
      }
    }

    // Soft delete message for everyone 1-to-1 or for Group
    static Future<void> softDeleteForEveryone({
      required bool isGroup,
      required Message message,
      String? receiverId,
      Group? group,
    }) async {
      try {
        final User currentUser = AuthController.instance.currentUser!;

        // Soft delete group message
        if (isGroup) {
          // Check the last msg group id to update the group info
          if (group?.lastMsg?.msgId == message.msgId) {
            // Replace the last msg
            group!.lastMsg = message;
            GroupApi.groupsRef
                .doc(group.groupId)
                .set(group.toUpdateMap(isDeleted: true), _setOptions);
          }

          // Soft delete the group message
          GroupApi.groupsRef
              .doc(group!.groupId)
              .collection('Messages')
              .doc(message.msgId)
              .set(message.toDeletedMap());

          // Delete group message files
          MessageApi.deleteMessageFiles();

          // Show feedback
          DialogHelper.showSnackbarMessage(
              SnackMsgType.success, 'message_deleted_successfully'.tr);
          return;
        }

        // Get the Chat node
        final Chat chat = ChatController.instance.getChat(receiverId!);

        // Check the last message id to update the chat node
        if (chat.msgId == message.msgId) {
          Future.wait([
            ChatApi.softDeleteChat(
              userId1: currentUser.userId,
              userId2: receiverId,
              msgId: message.msgId,
            ),
            // Update for another user
            ChatApi.softDeleteChat(
              userId1: receiverId,
              userId2: currentUser.userId,
              msgId: message.msgId,
            ),
          ]);
        }

        await Future.wait([
          // Soft delete for me
          _getCollectionRef(userId1: currentUser.userId, userId2: receiverId)
              .doc(message.msgId)
              .set(message.toDeletedMap(), _setOptions),
          // Soft delete for another user
          _getCollectionRef(userId1: receiverId, userId2: currentUser.userId)
              .doc(message.msgId)
              .set(message.toDeletedMap(), _setOptions),
        ]);

        // Delete message files
        MessageApi.deleteMessageFiles();

        // Show feedback
        DialogHelper.showSnackbarMessage(
            SnackMsgType.success, 'message_deleted_successfully'.tr);
      } catch (e) {
        DialogHelper.showSnackbarMessage(SnackMsgType.error, e.toString());
      }
    }

    // Delete message forever: 1-to-1 or for Group
    static Future<void> deleteMessageForever({
      required bool isGroup,
      required String msgId,
      Group? group,
      String? receiverId,
      Message? replaceMsg,
    }) async {
      try {
        final User currentUser = AuthController.instance.currentUser!;

        void successMessage() {
          DialogHelper.showSnackbarMessage(
              SnackMsgType.success, 'message_deleted_successfully'.tr);
        }

        // Delete Group Message
        if (isGroup) {
          await deleteGroupMessageForever(
            msgId: msgId,
            group: group!,
            replaceMsg: replaceMsg,
          );
          return;
        }

        // Update the current user chat node
        if (replaceMsg != null) {
          // Get chat instance
          final Chat chat = Chat(
            senderId: currentUser.userId,
            msgType: replaceMsg.type,
            lastMsg: replaceMsg.textMsg,
            msgId: replaceMsg.msgId,
          );

          // Update chat node.
          _firestore
              .collection('Users/${currentUser.userId}/Chats')
              .doc(receiverId)
              .set(chat.toMap(false), _setOptions);
        } else {
          ChatApi.resetChat(
            userId1: currentUser.userId,
            userId2: receiverId!,
          );
        }

        // Delete forever
        await _getCollectionRef(userId1: currentUser.userId, userId2: receiverId)
            .doc(msgId)
            .delete();

        // Delete message files
        MessageApi.deleteMessageFiles();

        // Show feedback
        successMessage();
      } catch (e) {
        DialogHelper.showSnackbarMessage(SnackMsgType.error, e.toString());
      }
    }

    static Future<void> deleteGroupMessageForever({
      required String msgId,
      required Group group,
      required Message? replaceMsg,
    }) async {
      //return;

      // Check last message replace the last msg
      if (replaceMsg != null) {
        group.lastMsg = replaceMsg;
        // Check deleted
        if (replaceMsg.isDeleted) {
          GroupApi.groupsRef
              .doc(group.groupId)
              .set(group.toUpdateMap(isDeleted: true), _setOptions);
        } else {
          GroupApi.groupsRef.doc(group.groupId).update(group.toUpdateMap());
        }
      } else {
        // Reset the last message
        group.lastMsg = null;
        GroupApi.groupsRef
            .doc(group.groupId)
            .set(group.toUpdateMap(), _setOptions);
      }

      // Delete the group msg forever
      GroupApi.groupsRef
          .doc(group.groupId)
          .collection('Messages')
          .doc(msgId)
          .delete();
    }

    static Future<void> deleteMessageFiles() async {
      try {
        final MessageController controller = Get.find();

        // Delete group messages
        List<Future> fileFutures = [];

        for (final msg in controller.messages) {
          if (msg.fileUrl.isNotEmpty) {
            fileFutures.add(AppHelper.deleteFile(msg.fileUrl));
            if (msg.type == MessageType.video) {
              fileFutures.add(AppHelper.deleteFile(msg.videoThumbnail));
            }
          }
        }

        // Check the list
        if (fileFutures.isNotEmpty) {
          await Future.wait(fileFutures);
        }
        debugPrint(
            'deleteMessageFiles() -> success, files: ${fileFutures.length}');
      } catch (e) {
        debugPrint('deleteMessageFiles() -> error: $e');
      }
    }
  }
