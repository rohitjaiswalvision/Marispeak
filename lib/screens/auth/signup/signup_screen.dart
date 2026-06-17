import 'dart:io';

import 'package:marispeaks/api/auth_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:marispeaks/api/user_api.dart';
import 'package:marispeaks/components/default_button.dart';
import 'package:marispeaks/helpers/app_helper.dart';
import 'package:get/get.dart';
import 'package:marispeaks/components/custom_appbar.dart';
import 'package:marispeaks/helpers/dialog_helper.dart';
import 'package:marispeaks/screens/auth/signup/controllers/signup_controller.dart';
import 'package:marispeaks/config/theme_config.dart';

class SignUpScreen extends GetView<SignUpController> {
  const SignUpScreen({super.key});

  void _signOut() {
    // Confirm sign out
    DialogHelper.showAlertDialog(
      title: Text('sign_out'.tr),
      icon: const Icon(IconlyLight.logout, color: primaryColor),
      content: Text('are_you_sure_you_want_to_sign_out'.tr),
      actionText: 'YES'.tr,
      action: () => AuthApi.signOut(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text('create_account'.tr),
        onBackPress: () => _signOut(),
        actions: [
          // Sign out
          IconButton(
            onPressed: () => _signOut(),
            icon: const Icon(IconlyLight.logout, color: Colors.white),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      // Pick image from camera/gallery
                      final File? resultFile =
                          await DialogHelper.showPickImageDialog(
                        isAvatar: true,
                      );
                      // Update file
                      controller.photoFile.value = resultFile;
                    },
                    child: Obx(() {
                      final photoFile = controller.photoFile.value;
                      final photoUrl = controller.photoUrl.value;

                      if (photoFile != null) {
                        return CircleAvatar(
                          radius: 70,
                          backgroundImage: FileImage(photoFile),
                        );
                      } else if (photoUrl.isNotEmpty) {
                        return CircleAvatar(
                          radius: 70,
                          backgroundImage: NetworkImage(photoUrl),
                        );
                      } else {
                        return const CircleAvatar(
                          radius: 70,
                          backgroundColor: primaryColor,
                          child: Icon(IconlyLight.camera, size: 85),
                        );
                      }
                    }),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text("profile_photo".tr,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium!
                          .copyWith(color: greyColor)),
                ),
                const SizedBox(height: 30),
                Text("fullname".tr,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  autofocus: true,
                  controller: controller.nameController,
                  decoration: InputDecoration(
                    hintText: 'enter_your_fullname'.tr,
                    prefixIcon: const Icon(IconlyLight.profile),
                  ),
                  validator: (String? name) {
                    if (name == null || name.trim().isEmpty) {
                      return 'enter_your_fullname'.tr;
                    }
                    return null;
                  },
                ),
                // const SizedBox(height: 20),

                // // <-- Username -->
                // Text("Your Phone Number",
                //     style: Theme.of(context).textTheme.titleMedium),
                // const SizedBox(height: 8),
                // Text(
                //           controller.phoneController.text,
                //           style: Theme.of(context).textTheme.bodyMedium,
                //         ),

                // const SizedBox(height: 20),
                // // Username field
                // TextFormField(
                //   autofocus: true,
                //   textInputAction: TextInputAction.search,
                //   controller: controller.usernameController,
                //   validator: AppHelper.usernameValidator,
                //   inputFormatters: AppHelper.usernameFormatter,
                //   decoration: InputDecoration(
                //     hintText: 'enter_your_username'.tr,
                //     prefixIcon: const Padding(
                //       padding: EdgeInsets.all(12.0),
                //       child: Icon(Icons.alternate_email, color: Colors.grey),
                //     ),
                //     suffixIcon: Padding(
                //       padding: const EdgeInsets.all(12.0),
                //       child: DefaultButton(
                //         height: 35,
                //         text: 'check'.tr,
                //         onPress: () {
                //           final String username =
                //               controller.usernameController.text.trim();
                //           // Check input
                //           if (username.isEmpty) {
                //             DialogHelper.showSnackbarMessage(
                //                 SnackMsgType.error, "enter_your_username".tr);
                //             return;
                //           }
                //           // Check username in database
                //           UserApi.checkUsername(username: username);
                //         },
                //       ),
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Obx(
        () => Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: defaultPadding,
            vertical: defaultPadding * 2,
          ),
          child: DefaultButton(
            height: 45,
            isLoading: controller.isLoading.value,
            width: double.maxFinite,
            text: 'create_account'.tr.toUpperCase(),
            onPress: () => controller.signUp(),
          ),
        ),
      ),
    );
  }



}

