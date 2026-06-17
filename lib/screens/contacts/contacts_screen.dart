import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:marispeaks/components/custom_appbar.dart';
import 'package:marispeaks/components/floating_button.dart';
import 'package:marispeaks/components/loading_indicator.dart';
import 'package:marispeaks/components/no_data.dart';
import 'package:marispeaks/models/user.dart';
import 'package:marispeaks/routes/app_routes.dart';
import 'package:marispeaks/helpers/routes_helper.dart';
import 'package:marispeaks/screens/contacts/controllers/contact_controller.dart';
import 'package:get/get.dart';
import 'components/contact_card.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final ContactController controller = Get.find();

  @override
  void initState() {
    super.initState();
    // Fetch contacts before the page fully renders
    controller.getContacts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text("contacts".tr),
        actions: [
          IconButton(
            icon: const Icon(IconlyLight.search, color: Colors.white),
            onPressed: () => Get.toNamed(AppRoutes.contactSearch),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        // Show loading indicator
        if (controller.isLoading.value) {
          return const LoadingIndicator();
        }

        // No contacts found
        if (controller.contacts.isEmpty) {
          return NoData(
            iconData: IconlyBold.profile,
            text: 'no_contacts'.tr,
          );
        }

        // List of contacts
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemCount: controller.contacts.length,
          itemBuilder: (context, index) {
            final User user = controller.contacts[index];
            return ContactCard(
              user: user,
              onPress: () {
                Get.back();
                RoutesHelper.toMessages(user: user);
              },
            );
          },
        );
      }),
      floatingActionButton: FloatingButton(
        icon: IconlyBold.addUser,
        onPress: () => Get.toNamed(AppRoutes.contactSearch),
      ),
    );
  }
}
