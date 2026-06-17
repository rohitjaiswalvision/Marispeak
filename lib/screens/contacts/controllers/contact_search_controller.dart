import 'package:marispeaks/helpers/app_helper.dart';
import 'package:flutter/material.dart';
import 'package:marispeaks/api/contact_api.dart';
import 'package:marispeaks/helpers/dialog_helper.dart';
import 'package:marispeaks/models/user.dart';
import 'package:get/get.dart';

class ContactSearchController extends GetxController {
  final RxBool isLoading = RxBool(false);
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController phoneController = TextEditingController();
  Rxn<User> contact = Rxn();

  void searchContact() async {
  isLoading.value = true;
  final query = phoneController.text.trim();
  if (query.isEmpty) {
    isLoading.value = false;
    return;
  }

  if (AppHelper.isValidPhoneNumber(query)) {
    // Search by phone number
    contact.value = await ContactApi.searchContactByPhone(query);
  } else {
    // Search by username
    contact.value = await ContactApi.searchContact(query);
  }
  isLoading.value = false;
}


  @override
  void onClose() {
    phoneController.dispose();
    super.onClose();
  }
}
