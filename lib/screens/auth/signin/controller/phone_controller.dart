import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:marispeaks/screens/auth/signin/otp_screen.dart';  // Import the OTP screen
class PhoneAuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final phoneController = TextEditingController();
  final otpController = TextEditingController();

  final isLoading = false.obs;
  var verificationId = ''.obs;
  final codeSent = false.obs;

 
void sendCodeToPhoneNumber(String phoneNumber) async {
  try {
    isLoading.value = true;

    // Validate the phone number format (ensure it starts with '+' and the country code)
    print('Phone number (before validation): $phoneNumber');
    if (phoneNumber.isEmpty || !phoneNumber.startsWith('+') || phoneNumber.length < 10) {
      Get.snackbar('Invalid', 'Please enter a valid phone number with country code.');
      isLoading.value = false;
      return; 
    }

    // Send OTP using the validated phone number
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber, 
      verificationCompleted: (PhoneAuthCredential credential) {},
      verificationFailed: (FirebaseAuthException e) {
        Get.snackbar('Error', e.message ?? 'Verification failed');
        isLoading.value = false;
      },
      codeSent: (String verificationId, int? resendToken) {
        this.verificationId.value = verificationId;
        codeSent.value = true;
        isLoading.value = false;
        Get.to(() => const OTPScreen());
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        this.verificationId.value = verificationId;
        isLoading.value = false;
      },
      timeout: const Duration(seconds: 60),
    );
  } catch (e) {
    isLoading.value = false;
    Get.snackbar('Error', 'Something went wrong');
  }
}




  void verifyOTP() async {
    try {
      isLoading.value = true;

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId.value,
        smsCode: otpController.text.trim(),
      );

      // Sign in the user with the credential
      await _auth.signInWithCredential(credential);
      _onLoginSuccess();
      isLoading.value = false;

      Get.snackbar("Success", "Phone number verified!");
    } catch (e) {
      isLoading.value = false;
      Get.snackbar("Error", e.toString());
    }
  }

  void resendOTP() {
    final phoneNumber = phoneController.text.trim();
    if (phoneNumber.isNotEmpty) {
      sendCodeToPhoneNumber(phoneNumber); // Re-call the existing method to resend OTP
    } else {
      Get.snackbar("Error", "Phone number is empty!");
    }
  }

  void _onLoginSuccess() {
    Get.offAllNamed('/main'); // Replace with your main route
  }
}
