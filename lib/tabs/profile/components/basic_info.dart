import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:marispeaks/components/cached_circle_avatar.dart';
import 'package:marispeaks/config/theme_config.dart';
import 'package:marispeaks/controllers/auth_controller.dart';
import 'package:marispeaks/models/user.dart';
import 'package:marispeaks/routes/app_routes.dart';
import 'package:get/get.dart';

class BasicInfo extends StatelessWidget {
  const BasicInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final User currentUser = AuthController.instance.currentUser!;

      return Padding(
        padding: const EdgeInsets.all(defaultPadding / 2),
        child: Column(
          children: [
            // Top section: Centered profile photo with edit button on the same line
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => Get.toNamed(AppRoutes.editProfile),
                  child: CachedCircleAvatar(
                    radius: 50,
                    iconSize: 60,
                    borderColor: primaryColor,
                    backgroundColor: primaryColor,
                    imageUrl: currentUser.photoUrl,
                  ),
                ),
                IconButton(
                  onPressed: () => Get.toNamed(AppRoutes.editProfile),
                  icon: const Icon(
                    IconlyLight.editSquare,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Bottom section: User information
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  currentUser.fullname,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => Get.toNamed(AppRoutes.editProfile),
                  child: Text(
                          currentUser.phone,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  currentUser.bio,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
