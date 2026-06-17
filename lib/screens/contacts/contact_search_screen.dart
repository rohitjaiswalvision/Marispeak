import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:marispeaks/api/contact_api.dart';
import 'package:marispeaks/components/custom_appbar.dart';
import 'package:marispeaks/components/floating_button.dart';
import 'package:marispeaks/components/loading_indicator.dart';
import 'package:marispeaks/components/no_data.dart';
import 'package:marispeaks/config/theme_config.dart';
import 'package:marispeaks/helpers/app_helper.dart';
import 'package:marispeaks/models/user.dart';
import 'package:marispeaks/helpers/routes_helper.dart';
import 'package:get/get.dart';
import 'components/contact_card.dart';
import 'controllers/contact_search_controller.dart';

class ContactSearchScreen extends StatelessWidget {
  const ContactSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ContactSearchController());

    return Scaffold(
      appBar: CustomAppBar(
        title: Text("search_contact".tr),
      ),
      body: Column(
        children: [
          // Search Contact by Phone Number or Username
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: defaultPadding,
              vertical: defaultPadding,
            ),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Form(
              key: controller.formKey,
              child: TextFormField(
                autofocus: true,
                onFieldSubmitted: (String value) => controller.searchContact(),
                textInputAction: TextInputAction.search,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Phone Number";  // Translation for phone number or username required
                  }
                  return null;
                },
                controller: controller.phoneController,
                decoration: InputDecoration(
                  hintText: 'Enter Phone with + country code',  // Updated placeholder
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: FloatingButton(
                    bgColor: secondaryColor,
                    icon: IconlyLight.search,
                    onPress: () => controller.searchContact(),
                  ),
                ),
              ),
            ),
          ),

          // Contact result
          Obx(() {
            if (controller.isLoading.value) {
              return const Padding(
                padding: EdgeInsets.only(top: 50),
                child: LoadingIndicator(size: 50),
              );
            } else if (controller.contact.value == null) {
              return Padding(
                padding: const EdgeInsets.only(top: 50),
                child: NoData(
                  iconData: IconlyLight.search,
                  text: 'No User Found! \n Phone must have country code'.tr,  // Translation for no contact found
                ),
              );
            }
            final User user = controller.contact.value!;

            return ContactCard(
              user: user,
              onPress: () {
                FocusScope.of(context).unfocus();
                print(user);

                ContactApi.addContact(userId: user.userId);

                RoutesHelper.toMessages(user: user).then((_) {
                  Get.back();
                  Get.back();
                });
              },
            );
          }),
        ],
      ),
    );
  }
}
