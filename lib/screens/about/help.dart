import 'dart:io';

import 'package:marispeaks/api/auth_api.dart';

import 'package:marispeaks/config/app_config.dart';

import 'package:marispeaks/api/user_api.dart';

import 'package:marispeaks/helpers/dialog_helper.dart';

import 'package:marispeaks/screens/IAPs/SubscriptionPage.dart';

import 'package:marispeaks/screens/about/mapsmari.dart';

import 'package:marispeaks/helpers/settings_provider.dart';

import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';

import 'package:flutter_iconly/flutter_iconly.dart';

import 'package:marispeaks/config/theme_config.dart';

import 'package:marispeaks/controllers/preferences_controller.dart';

import 'package:marispeaks/helpers/app_helper.dart';

import 'package:marispeaks/routes/app_routes.dart';

import 'package:marispeaks/screens/home/MainScreenUI.dart';

import 'package:marispeaks/screens/languages/languages_screen.dart';

import 'package:marispeaks/screens/ptt/agora_controller.dart';

import 'package:marispeaks/theme/app_theme.dart';

import 'package:get/get.dart';

import 'package:provider/provider.dart';



class Help extends StatefulWidget {

  @override

  _HelpState createState() => _HelpState();

}



class _HelpState extends State<Help> {


  final PreferencesController prefController = Get.find();


  @override

  Widget build(BuildContext context) {

    final bool isDarkMode = AppTheme.of(context).isDarkMode;

    final Color? iconColor = isDarkMode ? primaryColor : null;



    return WillPopScope(

      onWillPop: () async {

        mainScreenKey.currentState?.listenForUserLocations();

        return true;

      },

      child: Scaffold(

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
      "Help",
      style: TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    ),

    iconTheme: const IconThemeData(color: Colors.black),
  ),
),

        body: SingleChildScrollView(

          physics: const BouncingScrollPhysics(),

          // padding: const EdgeInsets.symmetric(

          //   vertical: defaultPadding,

          //   horizontal: defaultPadding / 2,

          // ), 

          child:
          
   Column(
     children: [
// Separator with text on top
SizedBox(
  width: double.infinity,
  height: 30, // height of the separator
  child: Stack(
    alignment: Alignment.centerLeft, // align text to left
    children: [
      Image.asset(
        "assets/maris/grey_seprator.png",
        width: double.infinity,
        height: 30,
        fit: BoxFit.cover, // fill width
      ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            " ",
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


GestureDetector(
 
  onTap: () => AppHelper.openPrivacyPage(),
  child: Container(
  width: double.infinity,
  height: 50, // adjust as needed
  padding: const EdgeInsets.only(
  left: 12,
  right: 12,
  top: 15,
  bottom: 0,
),
 
  child: Row(
    children: [
     
    // Text stacked vertically
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // vertically center
          crossAxisAlignment: CrossAxisAlignment.start, // align text left
          children: const [
            Text(
              "Privacy Policy",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),

      // Marispeak back image on the right
      Image.asset(
        "assets/maris/marispeakopen.png",
        width: 30,
        height: 30,
        fit: BoxFit.contain,
        color:  Theme.of(context).dividerColor,
      ),
    ],
  ),
),
),

Divider(
  thickness: 0.5,
  height: 0,
  color: Theme.of(context).dividerColor.withOpacity(0.3),
),

GestureDetector(
  onTap: () => AppHelper.openMailApp('support'.tr),

  child: Container(
  width: double.infinity,
  height: 50, // adjust as needed
  padding: const EdgeInsets.only(
  left: 12,
  right: 12,
  top: 15,
  bottom: 0,
),
 
  child: Row(
    children: [
     
    // Text stacked vertically
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // vertically center
          crossAxisAlignment: CrossAxisAlignment.start, // align text left
          children: const [
            Text(
              "Contact Support",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),

      // Marispeak back image on the right
      Image.asset(
        "assets/maris/marispeakopen.png",
        width: 30,
        height: 30,
        fit: BoxFit.contain,
        color:  Theme.of(context).dividerColor,
      ),
    ],
  ),
),
),

Divider(
  thickness: 0.5,
  height: 0,
  color: Theme.of(context).dividerColor.withOpacity(0.3),
),
// GestureDetector(
//   onTap: () {
//    Navigator.push(
//                         context,
//                         MaterialPageRoute(builder: (context) => SubscriptionPage()),
//                       );
//   },
//   child: Container(
//   width: double.infinity,
//   height: 50, // adjust as needed
//   padding: const EdgeInsets.only(
//   left: 12,
//   right: 12,
//   top: 15,
//   bottom: 0,
// ),
 
//   child: Row(
//     children: [
     
//     // Text stacked vertically
//       Expanded(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center, // vertically center
//           crossAxisAlignment: CrossAxisAlignment.start, // align text left
//           children: const [
//             Text(
//               "Terms and Conditions",
//               style: TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ],
//         ),
//       ),

//       // Marispeak back image on the right
//       Image.asset(
//         "assets/maris/marispeakopen.png",
//         width: 30,
//         height: 30,
//         fit: BoxFit.contain,
//       ),
//     ],
//   ),
// ),
// ),

//  const Divider(
//       height: 10,
//       thickness: 1,
//       color: Color.fromARGB(255, 235, 234, 234), // light grey
//     ),


GestureDetector(
 onTap: () => Get.toNamed(AppRoutes.about),
  child: Container(
  width: double.infinity,
  height: 50, // adjust as needed
  padding: const EdgeInsets.only(
  left: 12,
  right: 12,
  top: 15,
  bottom: 0,
),
 
  child: Row(
    children: [
     
    // Text stacked vertically
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // vertically center
          crossAxisAlignment: CrossAxisAlignment.start, // align text left
          children: const [
            Text(
              "About Marispeak",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),

      // Marispeak back image on the right
      Image.asset(
        "assets/maris/marispeakopen.png",
        width: 30,
        height: 30,
        fit: BoxFit.contain,
        color:  Theme.of(context).dividerColor,
      ),
    ],
  ),
),
),

 
Divider(
  thickness: 0.5,
  height: 0,
  color: Theme.of(context).dividerColor.withOpacity(0.3),
),

GestureDetector(
  onTap: () {
   Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => Mapsmari()),
                      );
  },
  child: Container(
  width: double.infinity,
  height: 50, // adjust as needed
  padding: const EdgeInsets.only(
  left: 12,
  right: 12,
  top: 15,
  bottom: 0,
),
 
  child: Row(
    children: [
     
    // Text stacked vertically
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // vertically center
          crossAxisAlignment: CrossAxisAlignment.start, // align text left
          children: const [
            Text(
              "Maps on Marispeak",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),

      // Marispeak back image on the right
      Image.asset(
        "assets/maris/marispeakopen.png",
        width: 30,
        height: 30,
        fit: BoxFit.contain,
        color:  Theme.of(context).dividerColor,
      ),
    ],
  ),
),
),

Divider(
  thickness: 0.5,
  height: 0,
  color: Theme.of(context).dividerColor.withOpacity(0.3),
),

GestureDetector(
 onTap: () => Get.toNamed(AppRoutes.agreement),

  child: Container(
  width: double.infinity,
  height: 50, // adjust as needed
  padding: const EdgeInsets.only(
  left: 12,
  right: 12,
  top: 15,
  bottom: 0,
),
 
  child: Row(
    children: [
     
    // Text stacked vertically
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // vertically center
          crossAxisAlignment: CrossAxisAlignment.start, // align text left
          children: const [
            Text(
              "Marispeak Agreement",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),

      // Marispeak back image on the right
      Image.asset(
        "assets/maris/marispeakopen.png",
        width: 30,
        height: 30,
        fit: BoxFit.contain,
        color:  Theme.of(context).dividerColor,
      ),
    ],
  ),
),
),


Divider(
  thickness: 0.5,
  height: 0,
  color: Theme.of(context).dividerColor.withOpacity(0.3),
),

GestureDetector(
  onTap: () {
   DialogHelper.showAlertDialog(
                          title: Text('delete_account'.tr),
                          titleColor: Colors.red,
                          icon: const Icon(IconlyLight.delete, color: Colors.red),
                          content: Text('are_you_sure_you_want_to_delete_your_account'.tr),
                          actionText: 'DELETE'.tr,
                          action: () {
                            UserApi.deleteUserAccount();
                            Get.back();
                          },
                        );
  },
  child: Container(
  width: double.infinity,
  height: 50, // adjust as needed
  padding: const EdgeInsets.only(
  left: 12,
  right: 12,
  top: 15,
  bottom: 0,
),
 
  child: Row(
    children: [
     
    // Text stacked vertically
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // vertically center
          crossAxisAlignment: CrossAxisAlignment.start, // align text left
          children: const [
            Text(
              "Delete Your Account",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),

      // Marispeak back image on the right
      Image.asset(
        "assets/maris/marispeakopen.png",
        width: 30,
        height: 30,
        fit: BoxFit.contain,
        color:  Theme.of(context).dividerColor,
      ),
    ],
  ),
),
),


Divider(
  thickness: 0.5,
  height: 5,
  color: Theme.of(context).dividerColor.withOpacity(0.3),
),

// const Divider(thickness: 1.0, height: 10, color: Color.fromARGB(255, 235, 234, 234),),
SizedBox(
  width: double.infinity,
  height: 400, // height of the separator
  child: Stack(
    alignment: Alignment.topLeft, // align text to left 
    children: [
      Image.asset( 
        "assets/maris/grey_seprator.png",
        width: double.infinity,
        height: 400,
        fit: BoxFit.cover, // fill width
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), // left padding
            child: Text(
        "Marispeak Version ${AppConfig.appVersion}",
        style: const TextStyle(
          fontSize: 14,
          color: Color.fromARGB(255, 93, 93, 93),
        ),
      ),
      ),
    ],
  ),
),

            ],

          ),

        ),

      ),

    );

  }

}

