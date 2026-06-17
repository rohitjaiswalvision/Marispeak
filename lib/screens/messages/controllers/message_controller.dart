import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:marispeaks/api/chat_api.dart';
import 'package:marispeaks/api/message_api.dart';
import 'package:marispeaks/api/user_api.dart';
import 'package:marispeaks/controllers/auth_controller.dart';
import 'package:marispeaks/helpers/app_helper.dart';
import 'package:marispeaks/helpers/encrypt_helper.dart';
import 'package:flutter/material.dart';
import 'package:marispeaks/helpers/dialog_helper.dart';
import 'package:marispeaks/helpers/routes_helper.dart';
import 'package:marispeaks/media/helpers/media_helper.dart';
import 'package:marispeaks/models/group.dart';
import 'package:marispeaks/models/location.dart';
import 'package:marispeaks/models/message.dart';
import 'package:marispeaks/models/user.dart';
import 'package:marispeaks/screens/home/CustomBottomSection.dart';
import 'package:marispeaks/screens/home/MainScreenUI.dart';
import 'package:marispeaks/screens/messages/message_screen.dart';
import 'package:marispeaks/screens/ptt/agora_controller.dart';
import 'package:marispeaks/tabs/groups/controllers/group_controller.dart';
import 'package:get/get.dart';


class MessageController extends GetxController {
  final bool isGroup;
  final User? user;

  MessageController({
    required this.isGroup,
    this.user,
  });

  // Variables
  final GroupController _groupController = Get.find();
  final chatFocusNode = FocusNode();
  final textController = TextEditingController();
  final scrollController = ScrollController();
  static String? currentOpenChatId;

  // Message vars
  final RxBool isLoading = RxBool(true);
  final RxList<Message> messages = RxList();
  StreamSubscription<List<Message>>? _stream;
  bool isVisible = true;

  // Obx & other vars
  final RxBool showEmoji = RxBool(false);
  final RxBool isTextMsg = RxBool(false);
  final RxBool isUploading = RxBool(false);
  final RxBool showScrollButton = RxBool(false);
  final RxList<File> documents = RxList([]);
  final RxList<File> uploadingFiles = RxList([]);
  final RxBool isChatMuted = RxBool(false);
  final Rxn<Message> selectedMessage = Rxn();
  final Rxn<Message> replyMessage = Rxn();
  // Normal vars
  bool isReceiverOnline = false;

  bool get isReplying => replyMessage.value != null;
  Group? get selectedGroup => _groupController.selectedGroup.value;
  void clearSelectedMsg() => selectedMessage.value = null;

  @override
  void onInit() {
    // Get selected group instance
    _groupController.getSelectedGroup();

    // Get messages
    _getMessages();
    // Check
    if (!isGroup) {
      _scrollControllerListener();
      _checkMuteStatus();
      ever(isTextMsg, (value) {
        UserApi.updateUserTypingStatus(value, user!.userId);
      });
    }
    super.onInit();

     // ✅ Track which chat is currently open
  if (isGroup) {
    currentOpenChatId = selectedGroup?.groupId;
  } else {
    currentOpenChatId = user?.userId;
  }

  }

  @override
  void onClose() {
    // Clear the previous one
  // ✅ Clear when leaving chat
  currentOpenChatId = null;
  
    _groupController.clearSelectedGroup();
    chatFocusNode.dispose();
    textController.dispose();
    scrollController.dispose();
    _stream?.cancel();
    super.onClose();
  }

  // Get Message Updates
  void _getMessages() {
  if (isGroup && selectedGroup != null) {
  final currentUserId = mainScreenKey.currentState?.User?.uid ?? '';

  _stream = MessageApi.getGroupMessages(
    selectedGroup!.groupId,
    currentUserId, // pass current user id for seenBy filtering
  ).listen(
    (event) {
      messages.value = event;
      isLoading.value = false;
      scrollToBottom();
    },
    onError: (e) => debugPrint(e.toString()),
  );
}
 else {
      _stream = MessageApi.getMessages(user!.userId).listen((event) {
        messages.value = event;
        isLoading.value = false;
        scrollToBottom();
      }, onError: (e) => debugPrint(e.toString()));
    }
  }

  // <-- Send Message Method -->
  Future<void> sendMessage(
      MessageType type, {
        File? file,
        String? text,
        String? gifUrl,
        Location? location,
        bool isRecAudio = false,
      }) async {
    // Vars
    String? textMsg, fileUrl, videoThumbnail;

if(Platform.isAndroid){
    // Show processing dialog
    if (file != null) {
      DialogHelper.showProcessingDialog(
          title: 'uploading'.tr, barrierDismissible: false);
    }
}

// if(Platform.isIOS){
  
// }
    // Check msg type
    switch (type) {
      case MessageType.text:
      // Get text msg
        textMsg = text;
        break;

      case MessageType.image:
      case MessageType.audio:
      case MessageType.doc:
      // Upload the file
        fileUrl = await _uploadFile(file!);
        break;

      case MessageType.video:
      // <-- Upload video & thumbnail -->
        fileUrl = await _uploadFile(file!);
        final File thumbnail = await MediaHelper.getVideoThumbnail(file.path);
        videoThumbnail = await _uploadFile(thumbnail);
        break;
      default:
      // Do nothing..
        break;
    }

    // <--- Build message --->
    final Message message = Message(
      msgId: AppHelper.generateID,
      type: type,
      textMsg: textMsg ?? '',
      fileUrl: fileUrl ?? '',
      gifUrl: gifUrl ?? '',
      location: location,
      videoThumbnail: videoThumbnail ?? '',
      senderId: AuthController.instance.currentUser!.userId,
      isRead: isReceiverOnline,
      isRecAudio: isRecAudio,
      replyMessage: replyMessage.value,
    );

    // Send message
    if (isGroup) {
      final Group group = selectedGroup!;
      // Check broadcast
    if (group.isBroadcast) {
          MessageApi.sendBroadcastMessage(group: group, message: message);
        } else {
          MessageApi.sendGroupMessage(
            group: group,
            message: message,
            visibleUserIds: mainScreenKey.currentState?.visibleUserIds ?? [],
          );
        }

    } else {
      MessageApi.sendMessage(message: message, receiver: user!);
    }

if(Platform.isAndroid){
    // Close processing dialog
    if (file != null) {
      DialogHelper.closeDialog();
    }
}
    // Reset values and update UI
    scrollToBottom();
    isTextMsg.value = false;
    textController.clear();
    uploadingFiles.clear();
    selectedMessage.value = null;
    replyMessage.value = null;
  }

  Future<void> forwardMessage(Message message) async {
    final List? contacts = await RoutesHelper.toSelectContacts(
        title: 'forward_to'.tr, showGroups: true, isBroadcast: false);
    if (contacts == null) return;
    // Decrypt private message on forward
    if (!isGroup) {
      message.textMsg = EncryptHelper.decrypt(message.textMsg, message.msgId);
    }
    MessageApi.forwardMessage(message: message, contacts: contacts);
  }

  void sendLocationExternally(Location location) {
  debugPrint('Sending external location: ${location.latitude}, ${location.longitude}');
  sendMessage(
    MessageType.location,
    location: location,
  );
}

  // <-- Hanlde file upload with loading status --->
  Future<String?> _uploadFile(File file) async {
    // Vars
    String? fileUrl;

    // Add single file to upload list
    uploadingFiles.add(file);

    // Update loading status
    isUploading.value = true;

    // Upload file
    fileUrl = await AppHelper.uploadFile(
      file: file,
      userId: AuthController.instance.currentUser!.userId,
    );

    // Update loading status
    isUploading.value = false;

    return fileUrl;
  }
  // END.

  // <-- Reply features -->

  void replyToMessage(Message message) {
    replyMessage.value = message;
    chatFocusNode.requestFocus();
  }

  void cancelReply() {
    replyMessage.value = null;
    selectedMessage.value = null;
    chatFocusNode.unfocus();
  }

  // END.

  // Handle emoji picker and keyboard
  void handleEmojiPicker() {
    if (showEmoji.value) {
      showEmoji.value = false;
      chatFocusNode.requestFocus();
      isVisible = false;
    } else {
      showEmoji.value = true;
      isVisible = true;
      chatFocusNode.unfocus();
    }
  }

  // Auto scroll the messages list to bottom
  void scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  // Listen scrollController updates
  void _scrollControllerListener() {
    scrollController.addListener(() {
      if (scrollController.position.pixels == 0.0) {
        // Update value
        showScrollButton.value = false;
      } else {
        showScrollButton.value = true;
      }
    });
  }

  Message? getReplaceMessage(Message deletedMsg) {
    Message? lastMsg;
    // Get last message
    if (messages.length > 1) {
      messages.remove(deletedMsg);
      lastMsg = messages.reversed.last;
    }
    return lastMsg;
  }

  Future<void> softDeleteForEveryone() async {
    DialogHelper.closeDialog();
    final Message message = selectedMessage.value!;

    MessageApi.softDeleteForEveryone(
      isGroup: isGroup,
      message: message,
      receiverId: user?.userId,
      group: selectedGroup,
    ).then((_) => selectedMessage.value = null);
  }

  Future<void> deleteMsgForMe() async {
    DialogHelper.closeDialog();
    final Message message = selectedMessage.value!;

    MessageApi.deleteMsgForMe(
      message: message,
      replaceMsg: getReplaceMessage(message),
      receiverId: user!.userId,
    ).then((_) => selectedMessage.value = null);
  }

  Future<void> deleteMessageForever() async {
    DialogHelper.closeDialog();
    final Message message = selectedMessage.value!;
    MessageApi.deleteMessageForever(
      isGroup: isGroup,
      msgId: message.msgId,
      group: selectedGroup,
      receiverId: user?.userId,
      replaceMsg: getReplaceMessage(message),
    ).then((_) => selectedMessage.value = null);
  }

  Future<void> clearChat() async {
    // Close confirm dialog
    DialogHelper.closeDialog();
    // Send the request
    ChatApi.clearChat(messages: messages, receiverId: user!.userId);
    messages.clear();
  }

  Future<void> muteChat() async {
    isChatMuted.toggle();
    ChatApi.muteChat(isMuted: isChatMuted.value, receiverId: user!.userId);
  }

  Future<void> _checkMuteStatus() async {
    final bool result = await ChatApi.checkMuteStatus(user!.userId);
    isChatMuted.value = result;
  }
}

class ColorGenerator {
  static final Map<String, Color> _senderColors = {};

  static Color getColorForSender(String senderId) {
    if (!_senderColors.containsKey(senderId)) {
      _senderColors[senderId] = _generateRandomColor();
    }
    return _senderColors[senderId]!;
  }

  static Color _generateRandomColor() {
    Random random = Random();
    final red = random.nextInt(256);
    final green = random.nextInt(256);
    final blue = random.nextInt(256);
    return Color.fromARGB(255, red, green, blue);
  }
}
