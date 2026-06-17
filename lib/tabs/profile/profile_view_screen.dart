import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:marispeaks/api/report_api.dart';
import 'package:marispeaks/api/user_api.dart';
import 'package:marispeaks/components/cached_circle_avatar.dart';
import 'package:marispeaks/components/custom_appbar.dart';
import 'package:marispeaks/config/theme_config.dart';
import 'package:marispeaks/controllers/app_controller.dart';
import 'package:marispeaks/controllers/report_controller.dart';
import 'package:marispeaks/helpers/date_helper.dart';
import 'package:marispeaks/helpers/routes_helper.dart';
import 'package:marispeaks/models/app_info.dart';
import 'package:marispeaks/models/user.dart';
import 'package:marispeaks/screens/calling/helper/call_helper.dart';
import 'package:marispeaks/theme/app_theme.dart';
import 'package:get/get.dart';

import 'components/action_button.dart';
import 'controllers/profile_view_controller.dart';

class ProfileViewScreen extends StatelessWidget {
  const ProfileViewScreen({
    super.key,
    required this.user,
    required this.isGroup,
  });

  final User user;
  final bool isGroup;

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = AppTheme.of(context).isDarkMode;

    final controller = Get.put(ProfileViewController(user.userId));
    final ReportController reportController = Get.find();

    return Scaffold(
      appBar: CustomAppBar(
        height: 50,
        title: Text('profile'.tr),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            vertical: defaultPadding * 2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header info
              Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profile photo
                    CachedCircleAvatar(
                      radius: 70,
                      iconSize: 60,
                      imageUrl: user.photoUrl,
                    ),
                    // Profile name
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: defaultPadding / 2),
                      child: Center(
                        child: Text(
                          user.fullname,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontSize: 26),
                        ),
                      ),
                    ),
                    // Profile @username
                    Center(
                      child:Text(
                          user.phone,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                    ),
                    const SizedBox(height: 8),
                //      Text("Phone".tr, style: Theme.of(context).textTheme.titleMedium),
                // const SizedBox(height: 8),
                // Container(
                //     padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                //     decoration: BoxDecoration(
                //       color: const Color.fromARGB(255, 248, 248, 248), // Light grey background color
                //       borderRadius: BorderRadius.circular(15.0), // Border radius of 20px
                //     ),
                //     child: Row(
                //       children: [
                //         const Padding(
                //           padding: EdgeInsets.all(12.0),
                //           child: Icon(Icons.phone, color: Colors.grey),
                //         ),
                //         Text(
                //           user.phone,
                //           style: Theme.of(context).textTheme.bodyMedium,
                //         ),
                //       ],
                //     ),
                //   ),
                    // Last seen
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: defaultPadding / 2,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDarkMode ? greyColor.withOpacity(0.5) : greyLight,
                        borderRadius: BorderRadius.circular(defaultRadius / 2),
                      ),
                      child: FutureBuilder<User?>(
                        future: UserApi.getUser(user.userId),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox.shrink();
                          }
                          // Get user
                          final User? updatedUser = snapshot.data;

                          if (updatedUser == null) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                              "${updatedUser.lastActive?.getLastSeenTime}");
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Actions: video call, voice call and message
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: defaultPadding,
                      ),
                      child: Obx(() {
                        final AppInfo appInfo = AppController.instance.appInfo;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Voice call
                            if (appInfo.allowVoiceCall)
                              ActionButton(
                                icon: IconlyBold.call,
                                title: 'audio'.tr,
                                onPress: () => CallHelper.makeCall(
                                    isVideo: false, user: user),
                              ),

                            // Video call
                            if (appInfo.allowVideoCall)
                              ActionButton(
                                icon: IconlyBold.video,
                                title: 'video'.tr,
                                onPress: () => CallHelper.makeCall(
                                    isVideo: true, user: user),
                              ),

                            // Message
                            ActionButton(
                              icon: IconlyBold.chat,
                              title: 'message'.tr,
                              onPress: () {
                                if (isGroup) {
                                  // Go to message page
                                  RoutesHelper.toMessages(user: user).then((_) {
                                    // Close group messages page
                                    Get.back();
                                    // Close group details page
                                    Get.back();
                                    // Close the current page
                                    Get.back();
                                  });
                                } else {
                                  RoutesHelper.toMessages(    
                                     isGroup: false,
                                            user: user,
                                          );
                                  // If 1-to-1 just close this page and return to messages page
                                //  Get.back();
                                }
                              },
                            ),
                          ],
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Description card
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(defaultPadding),
                child: Text(
                  user.bio,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge!
                      .copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              const Divider(),

              // Other info card
              ListTile(
                horizontalTitleGap: 8,
                leading: const Icon(IconlyLight.lock),
                title: Text('encrypted_message'.tr),
              ),
              const SizedBox(height: 8),
              Obx(() {
                final bool isBlocked = controller.isBlocked.value;

                return ListTile(
                  onTap: () => controller.toggleBlockUser(),
                  horizontalTitleGap: 8,
                  leading:
                      const Icon(IconlyLight.closeSquare, color: errorColor),
                  title: Text(
                    "${isBlocked ? 'unblock'.tr : 'block'.tr} ${user.fullname}",
                    style: const TextStyle(color: errorColor),
                  ),
                );
              }),
              const SizedBox(height: 8),
              ListTile(
                onTap: () => reportController.reportDialog(
                  type: ReportType.user,
                  userId: user.userId,
                ),
                horizontalTitleGap: 8,
                leading: const Icon(IconlyLight.infoSquare, color: errorColor),
                title: Text(
                  "${'report'.tr} ${user.fullname}",
                  style: const TextStyle(color: errorColor),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
