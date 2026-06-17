import 'package:marispeaks/config/theme_config.dart';
import 'package:flutter/material.dart';

class CustomPopup extends StatelessWidget {
  final String message;
  final VoidCallback onClose;

  const CustomPopup({super.key, required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 100, // Adjust position
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: primaryColor, fontSize: 16),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.red),
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
