import 'package:marispeaks/config/app_config.dart';
import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.width,
    this.height = 120,
    this.color,
  });

  final double? width;
  final double? height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppConfig.appLogo,
      width: width,
      height: height,
      color: color,
    );
  }
}
