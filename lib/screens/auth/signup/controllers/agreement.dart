import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marispeaks/routes/app_routes.dart';

class AgreementPage extends StatefulWidget {
  const AgreementPage({super.key});

  @override
  State<AgreementPage> createState() => _AgreementPageState();
}

class _AgreementPageState extends State<AgreementPage> {
  bool _hasAgreed = false;

  @override
  void initState() {
    super.initState();
    _checkAgreement();
  }

  Future<void> _checkAgreement() async {
    final prefs = await SharedPreferences.getInstance();
    final agreed = prefs.getBool('hasAgreed') ?? false;
    setState(() {
      _hasAgreed = agreed;
    });
  }

  Future<void> _agreeAndProceed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasAgreed', true);
    Get.offAllNamed(AppRoutes.mapHome);
  }

  @override
  Widget build(BuildContext context) {
    const Color appBlue = Color(0xFF007BFF);

    return Scaffold(
      // -------------------- APPBAR --------------------
    appBar: PreferredSize(
  preferredSize: const Size.fromHeight(60), // ✅ fixed height
  child: AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
    automaticallyImplyLeading: false,

    flexibleSpace: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          Theme.of(context).brightness == Brightness.dark
              ? "assets/maris/Rectangle_red_dark.png"
              : "assets/maris/Rectangle_red.png",
          fit: BoxFit.fill, // ✅ IMPORTANT (not cover)
        ),
      ],
    ),

    leading: IconButton(
      onPressed: () => Navigator.pop(context),
      icon: Image.asset(
        "assets/maris/marispeakback.png",
        width: 30,
        height: 30,
      ),
    ),

    title: const Text(
      "Marispeak Agreement",
      style: TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.w500,
        fontSize: 18,
      ),
    ),

    iconTheme: const IconThemeData(color: Colors.black),
  ),
),
      // -------------------- BODY --------------------
      body: SafeArea(
        child: Column(
          children: [
            // Top separator
            SizedBox(
              width: double.infinity,
              height: 30,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Image.asset(
                    "assets/maris/grey_seprator.png",
                    width: double.infinity,
                    height: 30,
                    fit: BoxFit.cover,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      " ",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 46, 46, 46),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Terms & Conditions
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: const Text(
                  '''
Marispeak – Terms & Conditions and Privacy Policy
Last Updated: December 3, 2024
Operated by Thalas Apps Pty Ltd
Contact: info@marispeak.com

1. Introduction
Welcome to Marispeak, a mobile and web-based application developed by Thalas Apps Pty Ltd. 
By downloading, accessing, or using Marispeak (the “App” or “Service”), you agree to comply with these Terms & Conditions and acknowledge our Privacy Policy. 
If you do not agree to these terms, please discontinue use of the App immediately. 
This document governs both the use of the Marispeak mobile application and associated website (www.marispeak.com), and the collection, use, and protection of personal information related to those services.

2. Important Notice
Marispeak is not intended to serve as an emergency communication system (e.g. Triple Zero (000), 911, or equivalent). 
In any serious, life-threatening, or urgent situation, you must not rely on Marispeak. 
Instead, immediately contact your local emergency services (for example, dial 000 in Australia, 911 in the U.S., or the applicable emergency number in your country).
Marispeak and its affiliates disclaim all liability for any loss, injury, harm, or death resulting from the use—or failure to use—this application in such situations.

3. User Responsibilities
Use the App only for lawful, marine-related activities. Do not disrupt or harm others. Manage your privacy and location settings responsibly. Some features require 4G/5G, GPS, and permissions.

4. Information We Collect
We collect personal and device data such as your name, email, GPS location, and app usage statistics. Communication data (PTT, voice, messages) is stored securely and used only for app functionality.

5. How We Use Your Information
Your data is used to operate and improve the App, provide customer support, send updates, and analyze usage for better performance. We do not sell or share your personal data for marketing.

6. Data Sources and Accuracy Disclaimer
Marispeak uses APIs from reliable, global data providers for weather, AIS, and marine data. 
While accuracy is prioritized, Thalas Apps Pty Ltd does not guarantee the completeness or reliability of third-party information.

7. Data Security
We use AES and End-to-End encryption to protect your data. Systems comply with international security standards, though absolute protection cannot be guaranteed.

8. Device Permissions
The App may request access to location, camera, microphone, storage, contacts, Bluetooth, and sensors. 
You can revoke permissions at any time, but functionality may be affected.

9. Children’s Privacy
Marispeak is not intended for users under 13. Any data collected from minors will be deleted upon discovery.

10. Limitation of Liability
Thalas Apps Pty Ltd disclaims all warranties and shall not be liable for indirect, incidental, or consequential damages resulting from use or inability to use the App.

11. International Use
Users must ensure local compliance when using Marispeak internationally. Governed by the laws of Victoria, Australia.

12. Updates to This Policy
We may periodically update this policy. Continued use signifies acceptance of the revised terms.

13. Contact Information
For questions or data concerns, contact: info@marispeak.com or visit www.marispeak.com

                  ''',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // -------------------- FLOATING BUTTON --------------------
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _hasAgreed
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _agreeAndProceed,
                  child: const Text(
                    'Agree',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
    );
  }
}
