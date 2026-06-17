import 'package:flutter/material.dart';
import 'package:marispeaks/config/app_config.dart';
import 'package:marispeaks/config/theme_config.dart';
import 'package:marispeaks/routes/app_routes.dart';
import 'package:get/get.dart';

class StartedScreen extends StatelessWidget {
  const StartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                height: 300,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/images/welcome_image.png"),
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                AppConfig.appName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
                child: Text(
                  "app_short_description".tr,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge!
                      .copyWith(color: greyColor, fontSize: 18),
                ),
              ),
              const SizedBox(height: 50),
              FittedBox(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () =>
                        Future(() => Get.offAllNamed(AppRoutes.signInOrSignUp)),
                    child: Row(
                      children: [
                        Text(
                          "get_started".tr,
                          style: const TextStyle(
                              fontSize: 18, color: Colors.white),
                        ),
                        const SizedBox(width: defaultPadding / 4),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.white70,
                        )
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}
