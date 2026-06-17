import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:marispeaks/components/cached_circle_avatar.dart';
import 'package:marispeaks/components/loading_indicator.dart';
import 'package:marispeaks/components/no_data.dart';
import 'package:marispeaks/config/theme_config.dart';
import 'package:marispeaks/models/user.dart';
import 'package:marispeaks/screens/contacts/controllers/contact_controller.dart';
import 'package:get/get.dart';

import '../controllers/create_group_controller.dart';

class ContactList extends GetView<CreateGroupController> {
  const ContactList({super.key});

  @override
  Widget build(BuildContext context) {
    final ContactController contactController = Get.find();

    return Obx(() {
      // Check loading
      if (contactController.isLoading.value) {
        return const LoadingIndicator();
      } else if (contactController.contacts.isEmpty) {
        return NoData(
          iconData: IconlyBold.profile,
          text: 'no_contacts'.tr,
        );
      }
      return ListView.separated(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: defaultPadding / 2),
        separatorBuilder: (_, __) => const Divider(height: 0),
        itemCount: contactController.contacts.length,
        itemBuilder: (context, index) {
          final User user = contactController.contacts[index];

          return Obx(
            () => ListTile(
              leading: CachedCircleAvatar(
                imageUrl: user.photoUrl,
                radius: 28,
              ),
              title: Text(
                user.fullname,
                style: TextStyle(
                    color: controller.isSelected(user) ? primaryColor : null),
              ),
              subtitle: Text('@${user.username}'),
              tileColor: controller.isSelected(user)
                  ? primaryColor.withOpacity(0.10)
                  : null,
              trailing: CupertinoCheckbox(
                value: controller.isSelected(user),
                onChanged: (bool? value) =>
                    controller.onCheckBoxChanged(value, user),
              ),
              onTap: () => controller.selectContact(user),
            ),
          );
        },
      );
    });
  }
}
