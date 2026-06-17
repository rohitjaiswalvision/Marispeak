import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:get/get.dart';
import 'package:marispeaks/screens/home/CustomBottomSection.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:marispeaks/components/floating_button.dart';
import 'package:marispeaks/components/loading_indicator.dart';
import 'package:marispeaks/components/no_data.dart';
import 'package:marispeaks/config/theme_config.dart';
import 'package:marispeaks/models/call_history.dart';
import 'package:marispeaks/routes/app_routes.dart';
import 'package:marispeaks/tabs/calls/controller/call_history_controller.dart';
import 'components/call_history_card.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final CallHistoryController controller = Get.put(CallHistoryController());
  bool showBackButton = false;

  @override
  void initState() {
    super.initState();
    _checkIfFromHome();
  }

  Future<void> _checkIfFromHome() async {
    final prefs = await SharedPreferences.getInstance();
    final fromHome = prefs.getBool('fromHome') ?? false;
    if (fromHome) {
      setState(() {
        print("coming from home, $fromHome");
        showBackButton = true;
      });
      await prefs.remove('fromHome');
    }
    if(!fromHome){
      setState(() {
        showBackButton = false;
         print("Not home, $fromHome");
    });
    }
  }
Widget _buildLeading() {
  if (showBackButton) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        setState(() => showBackButton = false);
        Get.back();
      },
    );
  } else {
    return const SizedBox(); // return empty widget
  }
}

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        setState(() => showBackButton = false);
        final prefs = await SharedPreferences.getInstance();
        await customBottomSection.currentState?.reconnectToLastChat(context);
        await prefs.remove('fromHome');
        Future.microtask(() => Get.back());
        return false; // prevent default pop; we're handling it
      },
      
      child: Scaffold(
     appBar: showBackButton
    ? AppBar(
        leading: _buildLeading(),
        title: Text(
          'Call History'.tr,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      )
    : null,

        body: Obx(() {
          if (controller.isLoading.value) {
            return const LoadingIndicator();
          } else if (controller.calls.isEmpty) {
            return NoData(
              iconData: IconlyBold.call,
              text: 'no_calls'.tr,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: defaultPadding),
            physics: const BouncingScrollPhysics(),
            itemCount: controller.calls.length,
            itemBuilder: (_, index) {
              final CallHistory call = controller.calls[index];
              return CallHistoryCard(call);
            },
          );
        }),
        floatingActionButton: FloatingButton(
          icon: IconlyBold.calling,
          onPress: () => Get.toNamed(AppRoutes.contacts),
        ),
      ),
    );
  }
}
