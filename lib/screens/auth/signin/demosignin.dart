import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PhoneAuthScreen extends StatefulWidget {
  @override
  _PhoneAuthScreenState createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  String? verificationId;
  String status = '';

  void sendCode() async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _phoneController.text.trim(),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-sign in for some Android numbers
        await FirebaseAuth.instance.signInWithCredential(credential);
        setState(() => status = "Auto-authenticated");
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => status = 'Verification failed: ${e.message}');
      },
      codeSent: (String verId, int? resendToken) {
        setState(() {
          verificationId = verId;
          status = "Code sent. Please enter it below.";
        });
      },
      codeAutoRetrievalTimeout: (String verId) {
        verificationId = verId;
      },
    );
  }

  void verifyCode() async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId!,
      smsCode: _codeController.text.trim(),
    );

    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
      setState(() => status = "✅ You are authenticated!");
    } catch (e) {
      setState(() => status = "❌ Invalid code");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Phone Auth')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isLoggedIn
            ? Center(child: Text("✅ You are authenticated!", style: TextStyle(fontSize: 24)))
            : Column(
                children: [
                  TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(labelText: "Phone number (+123...)"),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(onPressed: sendCode, child: const Text("Send Code")),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _codeController,
                    decoration: InputDecoration(labelText: "Enter SMS Code"),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(onPressed: verifyCode, child: const Text("Verify Code")),
                  const SizedBox(height: 20),
                  Text(status, style: const TextStyle(color: Colors.blue)),
                ],
              ),
      ),
    );
  }
}
