import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:marispeaks/api/report_api.dart';
import 'package:marispeaks/components/cached_circle_avatar.dart';
import 'package:marispeaks/components/circle_button.dart';
import 'package:marispeaks/config/theme_config.dart';
import 'package:marispeaks/controllers/report_controller.dart';
import 'package:marispeaks/helpers/date_helper.dart';
import 'package:marispeaks/helpers/dialog_helper.dart';
import 'package:marispeaks/helpers/routes_helper.dart';
import 'package:marispeaks/models/story/story.dart';
import 'package:marispeaks/models/user.dart';
import 'package:marispeaks/tabs/stories/controller/story_view_controller.dart';
import 'package:get/get.dart';
import 'package:story_view/story_view.dart';

class StoryViewScreen extends StatelessWidget {
  const StoryViewScreen({super.key, required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(StoryViewController(story: story));
    final ReportController reportController = Get.find();
    final User user = story.user!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(
            IconlyLight.arrowLeft2,
            color: Colors.white,
          ),
        ),
        title: GestureDetector(
          onTap: () {
            RoutesHelper.toProfileView(user, false).then(
              (value) => Get.back(),
            );
          },
          child: Row(
            children: [
              CachedCircleAvatar(
                radius: 20,
                borderColor: primaryColor,
                imageUrl: user.photoUrl,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullname,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Obx(
                    () => Text(controller.createdAt.formatDateTime,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        )),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          if (!story.isOwner)
            IconButton(
              onPressed: () => RoutesHelper.toMessages(user: user),
              icon: const Icon(
                IconlyLight.chat,
                color: Colors.white,
                size: 25,
              ),
            ),
          PopupMenuButton(
            icon: const Icon(Icons.more_horiz, color: Colors.white),
            onOpened: () => controller.storyController.pause(),
            itemBuilder: (_) => [
              PopupMenuItem(
                onTap: () => reportController.reportDialog(
                  type: ReportType.story,
                  story: controller.reportStoryItemData,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.flag,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text('report_this_story'.tr),
                  ],
                ),
              ),
              if (story.isOwner)
                PopupMenuItem(
                  onTap: () => _deleteStoryItem(controller),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text('delete_this_story'.tr),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(
              Icons.close, // The "X" button
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Story View
          StoryView(
            storyItems: controller.storyItems,
            indicatorHeight: IndicatorHeight.medium,
            indicatorOuterPadding: const EdgeInsets.all(10),
            controller: controller.storyController,
            onComplete: () => Get.back(),
            onStoryShow: (StoryItem item, index) {
              controller.getStoryItemIndex(index);
              controller.markSeen();
            },
          ),
          // Show seen by modal
          if (story.isOwner)
            Obx(() {
              return Container(
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.only(bottom: 16),
                child: CircleButton(
                  color: Colors.transparent,
                  onPress: () {
                    // Pause story
                    controller.storyController.pause();

                    // Show bottom modal
                    DialogHelper.showStorySeenByModal(
                      seenByList: controller.seenByList,
                      onDelete: () {
                        // Close modal
                        Get.back();
                        // Delete story item
                        _deleteStoryItem(controller);
                      },
                    );
                  },
                  icon: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(IconlyBold.show, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '${controller.seenByList.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  void _deleteStoryItem(StoryViewController controller) {
    // Confirm delete story item
    DialogHelper.showAlertDialog(
      titleColor: errorColor,
      title: Text('delete_this_story'.tr),
      content: Text('this_action_cannot_be_reversed'.tr),
      actionText: 'DELETE'.tr.toUpperCase(),
      action: () {
        Get.back(); // Close confirm dialog
        Get.back(); // Close story view page
        controller.deleteStoryItem();
      },
    );
  }
}
