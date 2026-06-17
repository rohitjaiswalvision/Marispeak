import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:marispeaks/screens/auth/signin/controller/phone_controller.dart';
import 'package:marispeaks/components/default_button.dart';

class OTPScreen extends StatelessWidget {
  const OTPScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Accessing the controller using GetX dependency injection
    final controller = Get.find<PhoneAuthController>();

    // Set transparent status bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/maris/marispeakenterotp.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 80),
                    Text(
                      "Phone Verification",
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      "Enter The Code Sent To Your Phone",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    // OTP Input Field
                    PinCodeTextField(
                      appContext: context,
                      length: 6,
                      controller: controller.otpController,
                      keyboardType: TextInputType.number,
                      autoFocus: true,
                      animationType: AnimationType.fade,
                      pinTheme: PinTheme(
                        shape: PinCodeFieldShape.box,
                        borderRadius: BorderRadius.circular(10),
                        fieldHeight: 50,
                        fieldWidth: 40,
                        activeFillColor: Colors.white,
                        selectedColor: Colors.blue,
                        activeColor: Colors.green,
                        inactiveColor: Colors.grey,
                      ),
                      onChanged: (value) {},
                      onCompleted: (value) {
                        controller.verifyOTP(); // Trigger OTP verification
                      },
                    ),
                    const SizedBox(height: 16),
                    // Resend OTP Button
                    TextButton(
                      onPressed: controller.resendOTP,
                      child: const Text(
                        "Resend OTP",
                        style: TextStyle(
                          color: Colors.white,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Verify Now Button
                    Obx(() => DefaultButton(
                          height: 50,
                          width: double.infinity,
                          isLoading: controller.isLoading.value,
                          onPress: controller.verifyOTP,
                          text: 'Verify Now',
                          textColor: Colors.white,
                        )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
