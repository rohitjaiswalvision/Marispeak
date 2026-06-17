import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:marispeaks/api/contact_api.dart';
import 'package:marispeaks/config/theme_config.dart';
import 'package:marispeaks/helpers/dialog_helper.dart';
import 'package:marispeaks/models/user.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

// class ContactController extends GetxController {
//   // Get the current instance
//   static ContactController instance = Get.find();

//   RxBool isLoading = RxBool(true);
//   RxList<User> contacts = RxList();
//   StreamSubscription<List<User>>? _stream;

//   @override
//   void onInit() {
//     _getContacts();
//     super.onInit();
//   }

//   @override
//   void dispose() {
//     _stream?.cancel();
//     super.dispose();
//   }

//   void _getContacts() {
//     _stream = ContactApi.getContacts().listen((event) {
//       contacts.value = event;
//       isLoading.value = false;

//       // Log the contacts fetched
//       print("Contacts fetched: ${contacts.length}"); // 0 shows here
//       for (var contact in contacts) {
//         print("Contact: ${contact.fullname}, ID: ${contact.userId}");
//       }
//     }, onError: (e) {
//       print("Error fetching contacts: $e");
//     });
//   }

//   Future<void> deleteContact(User contact) async {
//     final String title = 'delete_contact_from_your_contact_list'.trParams({
//       'contactName': contact.fullname,
//     });

//     DialogHelper.showAlertDialog(
//       barrierDismissible: false,
//       titleColor: errorColor,
//       title: Text('delete_this_contact'.tr),
//       icon: const Icon(IconlyLight.delete, color: errorColor),
//       content: Text('$title ${'this_action_cannot_be_reversed'.tr}'),
//       actionText: 'DELETE'.tr,
//       action: () {
//         Get.back();
//         ContactApi.deleteContact(contact.userId);
//       },
//     );
//   }
// }



class ContactController extends GetxController {
  // Get the current instance
  static ContactController instance = Get.find();

  RxBool isLoading = RxBool(true);
  RxList<User> contacts = RxList();
  StreamSubscription<List<User>>? _stream;

  @override
  void onInit() {
    
    super.onInit();
  }

  @override
  void dispose() {
    _stream?.cancel();
    super.dispose();
  }

  void getContacts() async {
    
    await [Permission.contacts].request();

    _stream = ContactApi.getContacts().listen((event) {
      contacts.value = event;
      isLoading.value = false;
    }, onError: (e) => debugPrint(e.toString()));
  }

  Future<void> deleteContact(User contact) async {
    final String title = 'delete_contact_from_your_contact_list'.trParams({
      'contactName': contact.fullname,
    });

    DialogHelper.showAlertDialog(
      barrierDismissible: false,
      titleColor: errorColor,
      title: Text('delete_this_contact'.tr),
      icon: const Icon(IconlyLight.delete, color: errorColor),
      content: Text('$title ${'this_action_cannot_be_reversed'.tr}'),
      actionText: 'DELETE'.tr,
      action: () {
        Get.back();
        ContactApi.deleteContact(contact.userId);
      },
    );
  }
}