import 'dart:io';

import 'package:marispeaks/api/group_api.dart';
import 'package:flutter/material.dart';
import 'package:marispeaks/helpers/app_helper.dart';
import 'package:get/get.dart';
import 'package:marispeaks/api/user_api.dart';
import 'package:marispeaks/controllers/auth_controller.dart';
// import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:marispeaks/helpers/dialog_helper.dart';
import 'package:marispeaks/routes/app_routes.dart';
import 'package:marispeaks/config/theme_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignUpController extends GetxController {
  // Variables
  final RxBool isLoading = RxBool(false);
  // SignUp info
  final Rxn<File> photoFile = Rxn();
  final RxString photoUrl = RxString('');
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  //final userId = AuthController.instance.currentUser!.userId;

  @override
  void onInit() {
    _setDisplayName();
    super.onInit();
  }

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    super.dispose();
  }

//   Future<void> requestATT() async {
//   final status = await AppTrackingTransparency.trackingAuthorizationStatus;

//   if (status == TrackingStatus.notDetermined) {
//     final result = await AppTrackingTransparency.requestTrackingAuthorization();
//     print('ATT Status: $result');
//   } else {
//     print('ATT already requested: $status');
//   }
// }

  void _setDisplayName() {
    // Get social login details
    final firebaseUser = AuthController.instance.firebaseUser;

    if (firebaseUser != null) {
      // Set the display name and username
      retrieveNameFromPrefs();

  if(nameController.text != ''){
      nameController.text = firebaseUser.displayName.toString();
      usernameController.text =
      AppHelper.sanitizeUsername(firebaseUser.displayName.toString());
    }

     // firebaseUser.updatePhone(phoneController.text);
      firebaseUser.updateDisplayName(nameController.text);
      // Check if a photo URL exists
      if (firebaseUser.photoURL != null && firebaseUser.photoURL!.isNotEmpty) {
        photoUrl.value = firebaseUser.photoURL!;

        // Optionally, download the image from the photoURL and set it to photoFile
        AppHelper.downloadImageFile(firebaseUser.photoURL!).then((file) {
          if (file != null) {
            photoFile.value = file;
          }
        });
      }
    }

   // requestATT();
  }

Future<void> signUp() async {
  if (!formKey.currentState!.validate()) return;

  isLoading.value = true;
  DialogHelper.showProcessingDialog(
    title: 'creating_account'.tr,
    barrierDismissible: false,
  );

  try {
    final result = await UserApi.createAccount(
      photoFile: photoFile.value,
      fullname: nameController.text.trim(),
      username: usernameController.text.trim(),
      phone: phoneController.text.trim(),
    );

    if (result == true) {
      await AuthController.instance.getCurrentUserAndLoadData();
      final user = AuthController.instance.currentUser!;

      if (user != null) {
        await GroupApi.ensureUserInDefaultGroup(user.userId);
      } else {
        debugPrint('User is null after loading.');
      }

      DialogHelper.closeDialog();
      DialogHelper.showAlertDialog(
        icon: const Icon(Icons.check_circle, color: primaryColor),
        title: Text('success'.tr),
        content: Text(
          'your_profile_account_has_been_successfully_created'.tr,
          style: const TextStyle(fontSize: 16),
        ),
        actionText: 'get_started'.tr.toUpperCase(),
        action: () => Future(() => Get.offAllNamed(AppRoutes.agreement)),
        showCancelButton: false,
        barrierDismissible: false,
      );
    } else {
      DialogHelper.closeDialog();
      DialogHelper.showSnackbarMessage(
        SnackMsgType.error,
        'failed_to_create_account'.trParams({'error': result.toString()}),
      );
    }
  } catch (e) {
    DialogHelper.closeDialog();
    DialogHelper.showSnackbarMessage(
      SnackMsgType.error,
      'Unexpected error: ${e.toString()}',
    );
  } finally {
    isLoading.value = false;
  }
}


Future<void> retrieveNameFromPrefs() async {
  final prefs = await SharedPreferences.getInstance();

  String? firstName = prefs.getString('first_name');
  String? lastName  = prefs.getString('last_name');
  String? phone     = prefs.getString('phone_number');

  // ✅ Only set full name if both parts are valid
  if (firstName != null && firstName.isNotEmpty &&
      lastName != null && lastName.isNotEmpty) {
    nameController.text = '$firstName $lastName';
  } else {
    nameController.text = ''; // leave empty so "Enter full name" hint shows
  }

  phoneController.text = phone ?? '';
}

}
