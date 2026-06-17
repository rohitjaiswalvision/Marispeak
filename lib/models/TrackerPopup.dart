import 'package:flutter/material.dart';

class TrackerPopup extends StatelessWidget {
  final String title;
  final String message;
  final String imagePath;
  final TextEditingController textController;
  final VoidCallback onProceed;
  final VoidCallback onClose;

  const TrackerPopup({
    super.key,
    required this.title,
    required this.message,
    required this.imagePath,
    required this.textController,
    required this.onProceed,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 10),

            // Image/Logo
            Image.asset(imagePath, width: 80, height: 80),

            SizedBox(height: 10),

            // Description Text
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),

            SizedBox(height: 10),

            // Input Field
            TextField(
              controller: textController,
              decoration: InputDecoration(
                hintText: "Enter text...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),

            SizedBox(height: 20),

            // Buttons: Proceed & Close
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: onClose,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text("Close"),
                ),
                ElevatedButton(
                  onPressed: onProceed,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: Text("Proceed"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
