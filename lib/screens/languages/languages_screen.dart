import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:get/get.dart';
import 'package:marispeaks/components/custom_appbar.dart';
import 'package:marispeaks/controllers/preferences_controller.dart';
import 'package:marispeaks/helpers/dialog_helper.dart';
import 'package:marispeaks/i18n/app_languages.dart';
import 'package:marispeaks/config/theme_config.dart';

class LanguagesScreen extends StatefulWidget {
  const LanguagesScreen({super.key});

  @override
  State<LanguagesScreen> createState() => _LanguagesScreenState();
}

class _LanguagesScreenState extends State<LanguagesScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine the number of columns based on screen width for responsiveness
    int crossAxisCount = MediaQuery.of(context).size.width > 600 ? 4 : 2;

    return Scaffold(
      appBar: CustomAppBar(
        title: Text('choose_a_language'.tr),
      ),
      body: Column(
        children: [

          // Body content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: (1 / 1),
                ),
                shrinkWrap: true,
                itemCount: AppLanguages().keys.length,
                itemBuilder: (context, index) {
                  // Get the language entry based on the index
                  final entry = AppLanguages().keys.entries.elementAt(index);
                  final String langKey = entry.key;
                  final String langName = entry.value['lang_name'] ?? langKey;

                  // Check if this language is selected
                  final bool isSelected =
                      PreferencesController.instance.langName == langName;

                  return Container(
                    margin: const EdgeInsets.all(10),
                    child: GestureDetector(
                      onTap: () {
                        // Confirm change language
                        DialogHelper.showAlertDialog(
                          title: Text('${'change_language'.tr}?'),
                          icon:
                              const Icon(Icons.translate, color: primaryColor),
                          content: Text(langName.tr),
                          actionText: 'change'.tr.toUpperCase(),
                          action: () {
                            Get.back();
                            PreferencesController.instance.locale.value =
                                Locale(langKey);
                          },
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor.withOpacity(0.1)
                              : lightThemeBgColor,
                          border: Border.all(
                            color: isSelected ? primaryColor : secondaryColor,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Flag Image
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(
                                width: 64,
                                height: 64,
                                child: Image.asset(
                                  'assets/flags/$langKey.png',
                                  fit: BoxFit
                                      .contain, // Ensure the entire image fits
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.translate,
                                    size: 48,
                                    color: greyColor,
                                  ),
                                ),
                              ),
                            ),
                            // Language Name
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text(
                                langName.tr,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? primaryColor
                                      : secondaryColor,
                                ),
                              ),
                            ),
                            // Optional: Show a checkmark or indicator if selected
                            if (isSelected)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Icon(
                                  IconlyBold.tickSquare,
                                  color: primaryColor,
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
