import 'package:flutter/material.dart';
import 'package:marispeaks/screens/auth/signin/signin_screen.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:marispeaks/screens/auth/signin/pushtalkintro.dart';

class Welcome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
       backgroundColor: Colors.black, 
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          Image.asset(
            'assets/maris/marispeakbg.png', // replace with your image path
            fit: BoxFit.cover,
          ),
          
            Container(
          color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.3), // Change to Colors.black.withOpacity(0.3) for dark
        ),
          // Button in Center
          // Custom Positioned Logo/Image
          Positioned(
            top: 150, // Adjust Y position here
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/maris/marispeakwelcome.png',
                width: 250,
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
          ),

           Positioned(
            top: 270, // Adjust Y position here
            left: 50,
            child: Image.asset(
                'assets/maris/marispeakcommunicate.png',
                width: 150,
                height: 150,
                fit: BoxFit.contain,
              ),
          ),
         // Bottom Center Button
         Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 80.0), // Adjust bottom spacing
                child: TextButton(
                  onPressed: () {
                   // Get.put(SignInController());
                    Get.to(() => Pushtalkintro(), transition: Transition.rightToLeft);
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: (Colors.transparent),
                  ),
                  child: Image.asset(
                    'assets/maris/marispeakgetstarted.png',
                    width: 240, // Set your desired width
                    height: 80,  // Set your desired height
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

        ],
      ),
    );
  }
}
