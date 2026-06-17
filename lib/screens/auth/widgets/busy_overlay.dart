import 'package:marispeaks/config/theme_config.dart';
import 'package:flutter/material.dart';

class BusyOverlay extends StatelessWidget{
  final Widget? child;
  final String title;
  final bool show;
  final int height;
  final double opacity;

  const BusyOverlay({
    Key? key,
    this.child,
    this.title = 'Please wait...',
    this.show = false,
    this.height = 0,
    this.opacity = 0.6
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if(child != null) child!,
        if(show)
          Container(
            height: height == 0 ? MediaQuery.of(context).size.height : height.toDouble(),
            width: MediaQuery.of(context).size.width,
            color: const Color(0xFF000000).withOpacity(opacity),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: darkThemeTextColor,),
                  const SizedBox(height: 20),
                  Text(title, style: const TextStyle(color: darkThemeTextColor, fontSize: 16,fontWeight: FontWeight.bold))
                ],
              ),
            ),
          )
      ],
    );
  }
}