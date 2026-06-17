import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marispeaks/components/default_button.dart';
import 'package:marispeaks/screens/auth/signin/controller/phone_controller.dart';
import 'package:marispeaks/config/app_config.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class PhoneSignInScreen extends StatefulWidget {
  const PhoneSignInScreen({super.key});

  @override
  State<PhoneSignInScreen> createState() => _PhoneSignInScreenState();
}

class _PhoneSignInScreenState extends State<PhoneSignInScreen> {
  late final PhoneAuthController controller;

  String NewPhone = '';

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
  controller = Get.put(PhoneAuthController());
   // _clearPrefs();
  }

 

  Future<void> _saveUserData(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('first_name', firstNameController.text.trim());
    await prefs.setString('last_name', lastNameController.text.trim());
    await prefs.setString('phone_number', phone);
    print('User data saved in SharedPreferences');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Image.asset(AppConfig.appLogo, width: 120, height: 120),
              const SizedBox(height: 20),
              Text(
                'Enter your Phone Number',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                textAlign: TextAlign.center,
                'You will receive a 6 digit code to verify. \nStandard rates may apply.',
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 20),

              // First & Last Name Row
              // Row(
              //   children: [
              //     Expanded(
              //       child: TextField(
              //         controller: firstNameController,
              //         decoration: const InputDecoration(
              //           labelText: 'First Name',
              //           border: OutlineInputBorder(),
              //         ),
              //       ),
              //     ),
              //     const SizedBox(width: 10),
              //     Expanded(
              //       child: TextField(
              //         controller: lastNameController,
              //         decoration: const InputDecoration(
              //           labelText: 'Last Name',
              //           border: OutlineInputBorder(),
              //         ),
              //       ),
              //     ),
              //   ],
              // ),

              const SizedBox(height: 16),

              // Phone Number Input
              IntlPhoneField(
                controller: controller.phoneController,
                initialCountryCode: 'PK',
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'Enter your phone number',
                  prefixIcon: Icon(Icons.phone),
                ),
                onChanged: (phone) {
                  NewPhone = phone.completeNumber;
                  print('Complete phone number: $NewPhone');
                },
                onCountryChanged: (country) {
                  print('Country changed to: ${country.code}');
                },
              ),

              const SizedBox(height: 16),

// Get Started / Verify OTP Button
Obx(() => DefaultButton(
      height: 50,
      width: double.infinity,
      isLoading: controller.isLoading.value,
      onPress: controller.codeSent.value
          ? controller.verifyOTP
          : () async {
              if (NewPhone.isEmpty || NewPhone.length < 10) {
                Get.snackbar('Missing Info', 'Please enter a valid phone number.');
                return;
              }

              await _saveUserData(NewPhone);
              controller.sendCodeToPhoneNumber(NewPhone);
            },
      text: controller.codeSent.value ? 'Verify OTP' : 'Get Started',
      textColor: Colors.white,
    )),
            ],
          ),
        ),
      ),
    );
  }
}
