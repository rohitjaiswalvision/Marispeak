import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:marispeaks/components/floating_button.dart';
import 'package:marispeaks/components/loading_indicator.dart';
import 'package:marispeaks/components/no_data.dart';
import 'package:marispeaks/config/theme_config.dart';
import 'package:marispeaks/helpers/dialog_helper.dart';
import 'package:marispeaks/models/group.dart';
import 'package:marispeaks/helpers/routes_helper.dart';
import 'package:marispeaks/tabs/groups/controllers/group_controller.dart';
import 'package:get/get.dart';

import '../components/group_card.dart';

class GroupsScreen extends GetView<GroupController> {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Obx(() {
          // Check loading
          if (controller.isLoading.value) {
            return const LoadingIndicator();
          } else if (controller.groups.isEmpty) {
            return NoData(
              iconData: IconlyBold.user3,
              text: 'no_groups'.tr,
            );
          }
          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: defaultPadding / 2),
            itemCount: controller.groups.length,
            itemBuilder: (context, index) {
              final Group group = controller.groups[index];
              return GroupCard(
                group: group,
                onPress: () async {
                  // Go to messages page
                  RoutesHelper.toMessages(
                      isGroup: true, groupId: group.groupId);
                },
              );
            },
          );
        }),
      ),
      floatingActionButton: FloatingButton(
        icon: Icons.group_add,
        onPress: () => DialogHelper.createGroupModal(),
      ),
    );
  }
}
