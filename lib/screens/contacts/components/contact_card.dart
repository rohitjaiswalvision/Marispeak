import 'package:flutter/material.dart';
import 'package:marispeaks/components/cached_circle_avatar.dart';
import 'package:marispeaks/config/theme_config.dart';
import 'package:marispeaks/models/user.dart';
import 'package:get/get.dart';

import '../controllers/contact_controller.dart';

class ContactCard extends GetView<ContactController> {
  const ContactCard({
    super.key,
    required this.user,
    required this.onPress,
  });

  final User user;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: defaultPadding / 2, vertical: defaultPadding / 2),
      onTap: onPress,
      leading: CachedCircleAvatar(
        imageUrl: user.photoUrl,
        radius: 28,
      ),
      title: Text(user.fullname),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: defaultPadding / 2),
        child: Text(
          '${user.phone}',
          style: TextStyle(
            color:
                Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.64),
          ),
        ),
      ),
      trailing: PopupMenuButton(
        itemBuilder: (_) => [
          PopupMenuItem(
            onTap: () => controller.deleteContact(user),
            child: Text('delete_this_contact'.tr),
          ),
        ],
      ),
    );
  }
}
