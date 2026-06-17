import 'package:marispeaks/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:get/get.dart';
import 'package:marispeaks/components/default_button.dart';
import 'package:marispeaks/components/header.dart';
import 'package:marispeaks/screens/auth/components/social_login_buttons.dart';
import 'package:marispeaks/screens/auth/components/or_divider.dart';
import 'package:marispeaks/screens/auth/signup/controllers/signup_with_email_controller.dart';
import 'package:marispeaks/helpers/app_helper.dart';
import 'package:marispeaks/routes/app_routes.dart';
import 'package:marispeaks/screens/auth/components/privacy_and_terms.dart';
import 'package:marispeaks/config/theme_config.dart';

class SignUpWithEmailScreen extends GetView<SignUpWithEmailController> {
  const SignUpWithEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        margin: const EdgeInsets.only(top: 60),
        padding: const EdgeInsets.all(defaultPadding),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                Image.asset(
                  AppConfig.appLogo,
                  width: 80,
                  height: 80,
                ),
                // const SizedBox(height: 16),
                // const Text(
                //   AppConfig.appName,
                //   style: TextStyle(
                //     fontSize: 26,
                //     fontWeight: FontWeight.bold,
                //     color: primaryColor,
                //   ),
                // ),
                Text(
                  'create_your_account'.tr,
                  style: const TextStyle(
                    color: Color.fromARGB(255, 255, 255, 255),
                  ),
                ),
                const SizedBox(height: 26),

                TextFormField(
                  keyboardType: TextInputType.emailAddress,
                  controller: controller.emailController,
                  validator: (String? value) {
                    // Validate email
                    if (GetUtils.isEmail(value ?? '')) {
                      return null;
                    }
                    return 'enter_valid_email_address'.tr;
                  },
                  decoration: InputDecoration(
                    labelText: 'email'.tr,
                    hintText: 'enter_your_email'.tr,
                    prefixIcon: const Icon(IconlyLight.message),
                  ),
                ),
                const SizedBox(height: 16),

                Obx(
                  () => TextFormField(
                    controller: controller.passwordController,
                    obscureText: controller.obscurePassword.value,
                    validator: AppHelper.validatePassword,
                    decoration: InputDecoration(
                      labelText: 'password'.tr,
                      hintText: 'enter_your_password'.tr,
                      prefixIcon: const Icon(IconlyLight.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          controller.obscurePassword.value
                              ? IconlyBold.show
                              : IconlyBold.hide,
                        ),
                        onPressed: () => controller.togglePasswordVisibility(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Obx(
                  () => TextFormField(
                    obscureText: controller.obscurePassword.value,
                    validator: controller.confirmPassword,
                    decoration: InputDecoration(
                      labelText: 'confirm_password'.tr,
                      hintText: 'confirm_your_password'.tr,
                      prefixIcon: const Icon(IconlyLight.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          controller.obscurePassword.value
                              ? IconlyBold.show
                              : IconlyBold.hide,
                        ),
                        onPressed: () => controller.togglePasswordVisibility(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Sign Up button
                Obx(
                  () => DefaultButton(
                    height: 50,
                    width: double.maxFinite,
                    isLoading: controller.isLoading.value,
                    onPress: () => controller.signUpWithEmailAndPassword(),
                    text: 'sign_up'.tr,
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('do_you_have_an_account'.tr),
                    TextButton(
                      onPressed: () => Get.offAllNamed(AppRoutes.signIn),
                      child: Header(
                        text: 'sign_in'.tr,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const OrDivider(),
                const SizedBox(height: 8),

                // <-- Social Logins -->
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: defaultPadding * 2),
                  child: SocialLoginButtons(),
                ),

                // Privacy Policy and Terms of Services
                const PrivacyAndTerms(isLogin: false),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
