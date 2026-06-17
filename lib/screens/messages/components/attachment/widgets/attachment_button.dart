import 'package:flutter/material.dart';
import 'package:marispeaks/config/theme_config.dart';

class AttachmentButton extends StatelessWidget {
  const AttachmentButton({
    super.key,
    this.onPress,
    this.icon, // This will now be a path to your image or a widget
    this.title,
    this.color,
  });

  // Params
  final Function()? onPress;
  final String? icon; // Change this to accept a string (image path)
  final String? title;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Button
        RawMaterialButton(
          onPressed: onPress,
          fillColor: color,
          padding: const EdgeInsets.all(2),
          shape: const CircleBorder(),
          elevation: 0.0,
          child: icon != null
              ? Image.asset(
                  icon!, // Use the provided image path
                  width: 34, // Adjust width if needed
                  height: 34, // Adjust height if needed
                 // color: primaryColor, // Optional: tint the image with the primary color
                )
              : const Icon(Icons.attach_file, color: primaryColor), // Default icon
        ),
        const SizedBox(height: 5),
        // Title
        Text(title ?? ''),
      ],
    );
  }
}
