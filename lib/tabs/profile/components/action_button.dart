import 'package:flutter/material.dart';
import 'package:marispeaks/components/circle_button.dart';
import 'package:marispeaks/config/theme_config.dart';

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    this.onPress,
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;
  final Function()? onPress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleButton(
          color: primaryColor.withOpacity(0.3),
          icon: Icon(icon, color: primaryColor),
          onPress: onPress,
        ),
        const SizedBox(height: 8),
        Text(title),
      ],
    );
  }
}
