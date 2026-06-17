import 'dart:io';
import 'package:marispeaks/api/auth_api.dart';
import 'package:marispeaks/screens/home/MainScreenUI.dart';
import 'package:marispeaks/api/user_api.dart';
import 'package:marispeaks/helpers/dialog_helper.dart';
import 'package:marispeaks/screens/home/CustomBottomSection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:marispeaks/config/theme_config.dart';
import 'package:marispeaks/controllers/preferences_controller.dart';
import 'package:marispeaks/helpers/app_helper.dart';
import 'package:marispeaks/routes/app_routes.dart';
import 'package:marispeaks/screens/IAPs/SubscriptionPage.dart';
import 'package:marispeaks/theme/app_theme.dart';
import 'package:get/get.dart';

import 'components/basic_info.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PreferencesController prefController = Get.find();
    final bool isDarkMode = AppTheme.of(context).isDarkMode;
    final Color? iconColor = isDarkMode ? primaryColor : null;

    return Scaffold(
      
    appBar: PreferredSize(
  preferredSize: const Size.fromHeight(60), // ✅ fixed height
  child: AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
    automaticallyImplyLeading: false,

    flexibleSpace: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          Theme.of(context).brightness == Brightness.dark
              ? "assets/maris/Rectangle_red_dark.png"
              : "assets/maris/Rectangle_red.png",
          fit: BoxFit.fill, // ✅ IMPORTANT (not cover)
        ),
      ],
    ),

    leading: IconButton(
      onPressed: () => Navigator.pop(context),
      icon: Image.asset(
        "assets/maris/marispeakback.png",
        width: 30,
        height: 30,
      ),
    ),

    title: const Text(
      "Profile",
      style: TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.w500,
        fontSize: 18,
      ),
    ),

    iconTheme: const IconThemeData(color: Colors.black),
  ),
),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

              SizedBox(
                width: double.infinity,
                height: 40, // height of the separator
                child: Stack(
                  alignment: Alignment.centerLeft, // align text to left
                  children: [
                    Image.asset(
                      "assets/maris/grey_seprator.png",
                      width: double.infinity,
                      height: 40,
                      fit: BoxFit.cover, // fill width
                    ),
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 0,), // left padding
                        child: Text(
                          "Account: ${customBottomSection.currentState?.userPhoneNumber ?? ''}",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 46, 46, 46),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const BasicInfo(),
                  Divider(
  thickness: 0.5,
  height: 0,
  color: Theme.of(context).dividerColor.withOpacity(0.3),
),

                ListTile(
                  dense: true, // makes it smaller vertically
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0), // optional
                  title: Text("Saved Routes"),
                  trailing: const Icon(IconlyLight.arrowRight2),
                  onTap: (){
                    Navigator.pop(context);
                    mainScreenKey.currentState?.showRoutesDialog(context); 
                  },
                ),
Divider(
  thickness: 0.5,
  height: 0,
  color: Theme.of(context).dividerColor.withOpacity(0.3),
),

                  // Terms of Use
                  ListTile(
                    title: const Text('How To Use'), dense: true, // makes it smaller vertically
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0), // optional
                    trailing: const Icon(IconlyLight.arrowRight2),
                    onTap: () => AppHelper.openTOS(),
                  ),
Divider(
  thickness: 0.5,
  height: 0,
  color: Theme.of(context).dividerColor.withOpacity(0.3),
),
                  
                  // Invite Friends
                  ListTile(
                    dense: true, // makes it smaller vertically
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    title: Text("Invite a friend"),
                  //  leading: Icon(Icons.share_outlined, color: iconColor),
                    trailing: const Icon(IconlyLight.arrowRight2),
                    onTap: () => AppHelper.shareApp(),
                  ),
Divider(
  thickness: 0.5,
  height: 0,
  color: Theme.of(context).dividerColor.withOpacity(0.3),
),
                  // Rate Us
                  ListTile(
                    dense: true, // makes it smaller vertically
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    title: Text(
                      '${'rate_us_on'.tr} ${Platform.isAndroid ? 'Google Play' : 'App Store'}',
                    ),
                   // leading: Icon(IconlyLight.star, color: iconColor),
                    trailing: const Icon(IconlyLight.arrowRight2),
                    onTap: () => AppHelper.rateApp(),
                  ),
Divider(
  thickness: 0.5,
  height: 0,
  color: Theme.of(context).dividerColor.withOpacity(0.3),
),
                  // Contact Support
                  ListTile(
                    dense: true, // makes it smaller vertically
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    title: Text('contact_support'.tr),
                  //  leading: Icon(IconlyLight.message, color: iconColor),
                    trailing: const Icon(IconlyLight.arrowRight2),
                    onTap: () => AppHelper.openMailApp('support'.tr),
                  ),
// Divider(
//   thickness: 0.5,
//   height: 0,
//   color: Theme.of(context).dividerColor.withOpacity(0.3),
// ),
//                   // About Us
//                   ListTile(
//                     dense: true, // makes it smaller vertically
//                   contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
//                     title: Text('about_us'.tr),
//                   //  leading: Icon(IconlyLight.dangerCircle, color: iconColor),
//                     trailing: const Icon(IconlyLight.arrowRight2),
//                     onTap: () => Get.toNamed(AppRoutes.about),
//                   ),
// Divider(
//   thickness: 0.5,
//   height: 0,
//   color: Theme.of(context).dividerColor.withOpacity(0.3),
// ),
//                   // Subscriptions
//                   ListTile(
//                     dense: true, // makes it smaller vertically
//                   contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
//                     title: Text('Subscriptions'.tr),
//                   //  leading: Icon(IconlyLight.moreSquare, color: iconColor),
//                     trailing: const Icon(IconlyLight.arrowRight2),
//                     onTap: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(builder: (context) => SubscriptionPage()),
//                       );
//                     },
//                   ),
Divider(
  thickness: 0.5,
  height: 0,
  color: Theme.of(context).dividerColor.withOpacity(0.3),
),
                  const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // left-right padding
            child: InkWell(
              onTap: () {
                DialogHelper.showAlertDialog(
                  title: Text('sign_out'.tr),
                  icon: const Icon(IconlyLight.logout, color: primaryColor),
                  content: Text('are_you_sure_you_want_to_sign_out'.tr),
                  actionText: 'YES'.tr,
                  action: () async {
                    await UserApi.updateUserPresence(false);
                    await AuthApi.signOut();
                  },
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 50, // button height
                width: double.infinity, // full width
                decoration: BoxDecoration(
                  color: Colors.transparent, // transparent background
                  border: Border.all(color: primaryColor, width: 1), // blue border
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      IconlyLight.logout,
                      color: primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "logout".tr,
                      style: const TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
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
        ],
      ),
    );
  }
}
