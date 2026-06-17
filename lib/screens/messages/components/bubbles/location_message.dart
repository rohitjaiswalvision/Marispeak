import 'package:marispeaks/models/message.dart';
import 'package:marispeaks/screens/home/MainScreenUI.dart';
import 'package:flutter/material.dart';

class LocationMessage extends StatelessWidget {
  const LocationMessage(this.message, {super.key});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final double latitude = message.location!.latitude;
    final double longitude = message.location!.longitude;

    return GestureDetector(
      onTap: () {
            Navigator.pop(context); // pop current screen
            Navigator.pop(context); // pop back to MainScreen

            Future.delayed(Duration(milliseconds: 300), () {
              mainScreenKey.currentState?.getDirections(latitude, longitude);
            }); 
          },    
          
      child: Container(
        padding: const EdgeInsets.only(bottom: 15),
        width: MediaQuery.of(context).size.width * 0.55,
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/icons/map_icon.png'),
          ),
        ),
      ),
    );
  }
}
