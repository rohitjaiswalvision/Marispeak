import 'dart:async';
import 'dart:io';

import 'package:marispeaks/api/contact_api.dart';
import 'package:marispeaks/api/story_api.dart';
import 'package:marispeaks/controllers/auth_controller.dart';
import 'package:marispeaks/media/helpers/media_helper.dart';
import 'package:marispeaks/models/story/story.dart';
import 'package:marispeaks/models/user.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class StoryController extends GetxController {
  // Get the current instance
  static StoryController instance = Get.find();

  final RxBool isLoading = RxBool(true);
  final RxList<Story> stories = RxList();
  StreamSubscription<List<Story>>? _stream;

  Story? story;
  dynamic storyItem;

  @override
  void onInit() {
    _getStories();
    super.onInit();
  }

  @override
  void onClose() {
    _stream?.cancel();
    super.onClose();
  }

  Future<void> _getStories() async {
      final status = await Permission.contacts.status;

  if (!status.isGranted) {
    debugPrint("📛 Contacts permission denied.");
    return;
  }
    final List<User> contacts = await ContactApi.getContacts().first;
    _stream = StoryApi.getStories(contacts).listen((event) {
      _updateStoriesList(event);
      isLoading.value = false;
    }, onError: (e) => debugPrint(e.toString()));
  }

  void _updateStoriesList(List<Story> event) {
    final User currentUser = AuthController.instance.currentUser!;

    stories.value = event;
    final Story? pinned =
        stories.firstWhereOrNull((e) => e.userId == currentUser.userId);
    if (pinned == null) return;
    stories.remove(pinned);
    stories.insert(0, pinned);
  }

  // Check if the current user is in the list of viewers
  bool get hasUnviewedStories {
    final User currentUser = AuthController.instance.currentUser!;

    if (stories.isEmpty) return false;
    for (var story in stories) {
      bool isViewed = story.viewers.contains(currentUser.userId);
      if (!isViewed && !story.isOwner) {
        return true;
      }
    }
    return false;
  }

  void viewStories() {
    if (hasUnviewedStories) {
      StoryApi.viewStories(stories);
    }
  }

  Future<void> uploadFileStory() async {
    // Open Camera Picker
    final File? file = await MediaHelper.openCameraScreen(Get.context!);
    if (file == null) return;

    // Send image story
    if (MediaHelper.isImage(file.path)) {
      StoryApi.uploadImageStory(file);
      return;
    }

    // Send video story
    if (MediaHelper.isVideo(file.path)) {
      StoryApi.uploadVideoStory(file);
      return;
    }
  }
}
