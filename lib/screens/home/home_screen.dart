import 'package:marispeaks/screens/contacts/controllers/contact_controller.dart';
import 'package:flutter/material.dart';
import 'package:marispeaks/api/user_api.dart';
import 'package:marispeaks/controllers/preferences_controller.dart';
import 'package:marispeaks/controllers/report_controller.dart';
import 'package:marispeaks/screens/home/CustomBottomSection.dart';
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
import 'package:flutter/services.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:get/get.dart';

import 'components/search_chat_input.dart';
import 'controller/home_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {

  @override
  void initState() {
    super.initState();


  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top]);
    // Init other controllers
    Get.put(ReportController(), permanent: true);
    Get.put(PreferencesController(), permanent: true);


    // Listen to incoming firebase push notifications
    FirebaseMessagingService.initFirebaseMessagingUpdates();
    // Update user presence
    UserApi.updateUserPresenceInRealtimeDb();

    WidgetsBinding.instance.addObserver(this);

    // Check if user contact is null and show modal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ContactController contactController = Get.find();
      if (contactController.contacts.isEmpty) {
        contactController.getContacts();
      //  _showContactModal();
      }
    });
  }

  @override
  void dispose() {
   // _rotateController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // void _showContactModal() {
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: Text('search_contacts_by_@username'.tr,
  //             style: TextStyle(fontSize: 18)),
  //         content: Text(
  //           "To start chatting, you must first search and add a contact using their @username or phone number. This ensures you can connect and communicate with the right person. Tap 'Go to Contacts'.",
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //             },
  //             child: Text("cancel".tr),
  //           ),
  //           ElevatedButton(
  //               onPressed: () {
  //                 Navigator.of(context).pop();
  //                 Get.toNamed(AppRoutes.contactSearch);
  //               },
  //               child: Text("go_to_contacts".tr,
  //                   style: TextStyle(color: Colors.white))),
  //         ],
  //       );
  //     },
  //   );
  // }
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
    return buildScaffold(context);
  }


Widget buildScaffold(BuildContext context) {
  final HomeController homeController = Get.find();
  final ChatController chatController = Get.find();
  final GroupController groupController = Get.find();
  final CallHistoryController callController = Get.find();
  final StoryController storyController = Get.find();
  final bool isDarkMode = AppTheme.of(context).isDarkMode;
  final User currentUser = AuthController.instance.currentUser!;

  return Obx(() {
    final int pageIndex = homeController.pageIndex.value;

    return WillPopScope(
      onWillPop: () async {
        await customBottomSection.currentState?.reconnectToLastChat(context);
        return true; // allow actual pop
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          centerTitle: false,
          toolbarHeight: pageIndex == 0 ? 80 : 65,
          title: Text(
            ['Messages', 'Groups', 'Status', 'Calls History', 'Profile'][pageIndex],
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
          ),
          actions: [
            if (pageIndex != 3) // hide Swipe → on Calls History
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      "Swipe",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
            if (pageIndex == 0 || pageIndex == 3)
              IconButton(
                icon: Icon(
                  homeController.showSearchBar.value ? Icons.close : Icons.search,
                  color: Colors.black,
                ),
                onPressed: () {
                  homeController.showSearchBar.toggle();
                },
              ),
            if (pageIndex == 3) const ClearCallsButton(),
          ],
          bottom: homeController.showSearchBar.value
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(50),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      onChanged: (value) {
                        // Search logic
                      },
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            homeController.showSearchBar.value = false;
                          },
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                )
              : null,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: homeController.pageController,
                  onPageChanged: (index) {
                    homeController.pageIndex.value = index;
                  },
                  children: homeController.pages,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  });
}


}
