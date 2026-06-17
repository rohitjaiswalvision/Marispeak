import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:marispeaks/helpers/app_helper.dart';
import 'package:marispeaks/config/theme_config.dart';

class PrivacyAndTerms extends StatelessWidget {
  const PrivacyAndTerms({super.key, required this.isLogin});

  final bool isLogin;

  @override
  Widget build(BuildContext context) {
    // Vars
    final String loginOrSignup = isLogin ? 'sign_in'.tr : 'sign_up'.tr;

    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        Text(
          'by_login_or_signup_you_agree_with_our'
              .trParams({'loginOrSignup': loginOrSignup.toLowerCase()}),
        ),
        GestureDetector(
            onTap: () => AppHelper.openPrivacyPage(),
            child: Text('privacy_policy'.tr,
                style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0), fontWeight: FontWeight.bold))),
        // Text('_and_'.tr),
        // GestureDetector(
        //   onTap: () => AppHelper.openTermsPage(),
        //   child: Text(
        //     'terms_of_service'.tr,
        //     style: const TextStyle(color: primaryColor),
        //   ),
        // ),
      ],
    );
  }
}
