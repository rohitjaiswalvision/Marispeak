import 'dart:io';

import 'package:flutter/material.dart';
import 'package:marispeaks/models/user.dart';
import 'package:get/get.dart';
import 'package:marispeaks/api/user_api.dart';
import 'package:marispeaks/controllers/auth_controller.dart';
import 'package:marispeaks/helpers/dialog_helper.dart';

class EditProfileController extends GetxController {
  // Vars
  final RxBool isLoading = RxBool(false);
  final RxBool isExtended = RxBool(false);
  final Rxn<File> photoFile = Rxn();
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final usernameController = TextEditingController();
  final phoneController = TextEditingController();
  final bioController = TextEditingController();

  @override
  void onInit() {
    _loadInitialData();
    super.onInit();
  }

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    bioController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    final User currentUser = AuthController.instance.currentUser!;

    nameController.text = currentUser.fullname;
    usernameController.text = currentUser.username;
    phoneController.text = currentUser.phone;
    bioController.text = currentUser.bio;
  }

  Future<void> updateAccount() async {
    // Check the form
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;

    // Update user account
    final result = await UserApi.updateAccount(
      photoFile: photoFile.value,
      fullname: nameController.text.trim(),
      username: usernameController.text.trim(),
      phone: phoneController.text.trim(),
      bio: bioController.text.trim(),
    );

    isLoading.value = false;

    // Check result
    if (result) {
      Get.back();
      // Show success message
      DialogHelper.showSnackbarMessage(
          SnackMsgType.success, 'account_updated_successfully'.tr);
    } else {
      // Show error message
      DialogHelper.showSnackbarMessage(SnackMsgType.error, result.toString());
    }
  }
}
