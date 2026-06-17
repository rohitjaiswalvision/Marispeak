import 'package:flutter/material.dart';
import 'package:marispeaks/api/user_api.dart';
import 'package:marispeaks/components/badge_indicator.dart';
import 'package:marispeaks/controllers/preferences_controller.dart';
import 'package:marispeaks/controllers/report_controller.dart';
import 'package:marispeaks/tabs/calls/components/clear_calls_button.dart';
import 'package:marispeaks/tabs/calls/controller/call_history_controller.dart';
import 'package:marispeaks/tabs/groups/controllers/group_controller.dart';
import 'package:marispeaks/tabs/stories/controller/story_controller.dart';
import 'package:marispeaks/theme/app_theme.dart';
import 'package:marispeaks/controllers/auth_controller.dart';
import 'package:marispeaks/config/app_config.dart';
import 'package:marispeaks/models/user.dart';
import 'package:marispeaks/components/app_logo.dart';
import 'package:marispeaks/components/cached_circle_avatar.dart';
import 'package:marispeaks/routes/app_routes.dart';
import 'package:marispeaks/tabs/chats/controllers/chat_controller.dart';
import 'package:marispeaks/services/firebase_messaging_service.dart';
import 'package:marispeaks/config/theme_config.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:get/get.dart';

import 'components/search_chat_input.dart';
import 'controller/home_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    // Init other controllers
    Get.put(ReportController(), permanent: true);
    Get.put(PreferencesController(), permanent: true);

    // Listen to incoming firebase push notifications
    FirebaseMessagingService.initFirebaseMessagingUpdates();

    // Update user presence
    UserApi.updateUserPresenceInRealtimeDb();

    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // <-- Handle the user presence -->
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
      // Set User status Online
        UserApi.updateUserPresence(true);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      // Set User status Offline
        UserApi.updateUserPresence(false);
        break;
    }
  }
  // END

  @override
  Widget build(BuildContext context) {
    // Get Controllers
    final HomeController homeController = Get.find();
    final ChatController chatController = Get.find();
    final GroupController groupController = Get.find();
    final CallHistoryController callController = Get.find();
    final StoryController storyController = Get.find();

    // Others
    final bool isDarkMode = AppTheme.of(context).isDarkMode;
    final Color color = isDarkMode ? primaryColor : Colors.white;

    return Obx(() {
      // Get page index
      final int pageIndex = homeController.pageIndex.value;
      // Get current user
      final User currentUer = AuthController.instance.currentUser!;

      return Scaffold(
        appBar: AppBar(
          centerTitle: false,
          toolbarHeight: pageIndex == 0 ? 80 : 65,
          title: Row(
            children: [
              // App logo
              AppLogo(width: 35, height: 35, color: color),
              const SizedBox(width: 16),
              // App name
              Text(
                AppConfig.appName,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge!
                    .copyWith(color: color, fontSize: 20),
              ),
            ],
          ),
          actions: [
            // Change Theme Mode
            if (pageIndex == 0)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: () =>
                      PreferencesController.instance.isDarkMode.toggle(),
                  icon: const Icon(Icons.brightness_6, color: Colors.white),
                ),
              ),

            // Clear call log
            if (pageIndex == 3) const ClearCallsButton(),

            // Go to session page
            if (pageIndex == 4)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: () => Get.toNamed(AppRoutes.session),
                  icon: const Icon(IconlyLight.logout, color: Colors.white),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Search Chats
              if (pageIndex == 0) const SearchChatInput(),
              // Show Banner Ad
              // Show the body content
              Expanded(child: homeController.pages[pageIndex]),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            homeController.pageIndex.value = 2;
            storyController.viewStories();
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Story Image as Background
              // ClipOval(
              //   child: Image.asset(
              //     'assets/images/story_background.png', // Replace with your story background image
              //     width: 60,
              //     height: 60,
              //     fit: BoxFit.cover,
              //   ),
              // ),
              // Stories Icon
              Image.asset(
                'assets/icons/story.png',
                width: 150,
                // color: pageIndex == 2 ? primaryColor : primaryColor.withOpacity(0.5),
              ),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 6.0,
          color: PreferencesController.instance.isDarkMode.value
              ? threeColor
              : lightThemeBgColor,
          child: SizedBox(
            height: 60, // Adjust height as needed
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Left Side Navigation Items
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MaterialButton(
                      minWidth: 40,
                      onPressed: () {
                        homeController.pageIndex.value = 0;
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          BadgeIndicator(
                            icon: pageIndex == 0 ? IconlyBold.chat : IconlyLight.chat,
                            iconColor: pageIndex == 0 ? primaryColor : primaryColor.withOpacity(0.5),
                            isNew: chatController.newMessage,
                          ),
                          Text(
                            'chats'.tr,
                            style: TextStyle(
                              color: pageIndex == 0
                                  ? primaryColor
                                  : primaryColor.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    MaterialButton(
                      minWidth: 40,
                      onPressed: () {
                        homeController.pageIndex.value = 1;
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          BadgeIndicator(
                            icon: pageIndex == 1 ? IconlyBold.user3 : IconlyLight.user3,
                            isNew: groupController.newMessage,
                            iconColor: pageIndex == 1 ? primaryColor : primaryColor.withOpacity(0.5),
                          ),
                          Text(
                            'groups'.tr,
                            style: TextStyle(
                              color: pageIndex == 1
                                  ? primaryColor
                                  : primaryColor.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Right Side Navigation Items
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MaterialButton(
                      minWidth: 40,
                      onPressed: () {
                        homeController.pageIndex.value = 3;
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          BadgeIndicator(
                            icon: pageIndex == 3 ? IconlyBold.call : IconlyLight.call,
                            isNew: callController.newCalls.isNotEmpty,
                            iconColor: pageIndex == 3 ? primaryColor : primaryColor.withOpacity(0.5),
                          ),
                          Text(
                            'calls'.tr,
                            style: TextStyle(
                              color: pageIndex == 3
                                  ? primaryColor
                                  : primaryColor.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    MaterialButton(
                      minWidth: 40,
                      onPressed: () {
                        homeController.pageIndex.value = 4;
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CachedCircleAvatar(
                            imageUrl: currentUer.photoUrl,
                            iconSize: currentUer.photoUrl.isEmpty ? 22 : null,
                            borderColor: pageIndex == 4
                                ? primaryColor
                                : primaryColor.withOpacity(0.5),
                            radius: 12,
                          ),
                          Text(
                            'profile'.tr,
                            style: TextStyle(
                              color: pageIndex == 4
                                  ? primaryColor
                                  : primaryColor.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
