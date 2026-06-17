import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:marispeaks/config/theme_config.dart';

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 20),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: 15.0),
              child: Divider(
                  indent: 20.0,
                  endIndent: 5.0,
                  thickness: 1,
                  color: Colors.black45
              ),
            ),
          ),
          Text(
              'or'.tr,
              style: TextStyle(
                  decoration: TextDecoration.none,
                  fontSize: 12,
                  color: const Color.fromARGB(255, 0, 0, 0)
              )
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: 15.0),
              child: Divider(
                  indent: 5.0,
                  endIndent: 20.0,
                  thickness: 1,
                  color: Colors.black45),
            ),
          ),
        ],
      ),
    );
  }
}
