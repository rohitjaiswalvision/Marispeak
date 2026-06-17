import 'package:flutter/material.dart';
import 'package:marispeaks/screens/auth/signin/signin_screen.dart';
import 'package:marispeaks/screens/auth/signin/Aisintro.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:marispeaks/screens/auth/signin/controller/signin_controller.dart';


class Weatherintro extends StatefulWidget {
  @override
  _WeatherintroState createState() => _WeatherintroState();
}

class _WeatherintroState extends State<Weatherintro> {
  final _signInScreen = Aisintro();

   @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Preload the screen (not strictly necessary unless expensive)
      final _ = _signInScreen;

      // ✅ Now it's safe to use context here
      precacheImage(AssetImage('assets/maris/introaisbg.png'), context);
    });
  }


  Widget build(BuildContext context) {
    return Scaffold(
       backgroundColor: Colors.black, 
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          Image.asset(
            'assets/maris/weatherintro.png', // replace with your image path
            fit: BoxFit.cover,
          ),
          // Button in Center
          // Custom Positioned Logo/Image
          Positioned(
            top: 10, // Adjust Y position here
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/maris/marispeakdots3.png',
                width: 250,
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
          ),

           Positioned(
            top: 100, // Adjust Y position here
            left: 0,
            right: 0,
            child: Image.asset(
                'assets/maris/weathertext.png',
                width: 70,
                height: 60,
               // fit: BoxFit.contain,
              ),
          ),

           Positioned(
            top: 180, // Adjust Y position here
            left: 0,
            right: 0,
            child: Image.asset(
                'assets/maris/weathertextinfo.png',
                width: 150,
                height: 140,
                fit: BoxFit.contain,
              ),
          ),
         // Bottom Center Button
         Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(right:20, bottom: 40.0), // Adjust bottom spacing
                child: TextButton(
                  onPressed: () {
                  //  Get.put(SignInController());
                    Get.to(() => Aisintro(), transition: Transition.rightToLeft);
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: (Colors.transparent),
                  ),
                  child: Image.asset(
                    'assets/maris/marispeaknext.png',
                    width: 140, // Set your desired width
                    height: 80,  // Set your desired height
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

          Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 20,bottom: 57.0),
                  child: TextButton(
                    onPressed: () {
                      Get.put(SignInController());
                      Get.to(() => PhoneSignInScreen(), transition: Transition.rightToLeft);
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      splashFactory: NoSplash.splashFactory,
                      overlayColor: (Colors.transparent),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          'assets/maris/rect_main.png',
                          width: 140,
                          height: 45,
                          fit: BoxFit.fill,
                        ),
                        Text(
                          'Skip',
                          style: TextStyle(
                            color: const Color.fromARGB(255, 7, 163, 206),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
