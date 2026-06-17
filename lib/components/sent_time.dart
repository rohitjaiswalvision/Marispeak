import 'package:flutter/material.dart';
import 'package:marispeaks/helpers/date_helper.dart';
import 'package:marispeaks/config/theme_config.dart';

class SentTime extends StatelessWidget {
  const SentTime({super.key, this.time});

  final DateTime? time;

  @override
  Widget build(BuildContext context) {
    // Check time
    if (time == null) return const SizedBox.shrink();

    return Text(
      time!.formatDateTime,
      style: const TextStyle(fontSize: 12, color: greyColor),
    );
  }
}
