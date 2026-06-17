import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:marispeaks/config/theme_config.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
    this.size = 25,
    this.color = primaryColor,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SpinKitWave(size: size, color: color);
  }
}
