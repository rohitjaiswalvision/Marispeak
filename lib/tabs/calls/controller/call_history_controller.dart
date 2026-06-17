import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:marispeaks/api/call_history_api.dart';
import 'package:marispeaks/config/theme_config.dart';
import 'package:marispeaks/helpers/dialog_helper.dart';
import 'package:marispeaks/models/call_history.dart';
import 'package:get/get.dart';

class CallHistoryController extends GetxController {
  // Vars
  final RxBool isLoading = RxBool(true);
  final RxList<CallHistory> calls = RxList();
  StreamSubscription<List<CallHistory>>? _stream;

  List<CallHistory> get newCalls => calls.where((call) => call.isNew).toList();

  @override
  void onInit() {
    _getCallHistory();
    super.onInit();
  }

  @override
  void onClose() {
    _stream?.cancel();
    super.onClose();
  }

  void _getCallHistory() {
    _stream = CallHistoryApi.getCallHistory().listen((event) {
      calls.value = event;
      isLoading.value = false;
    }, onError: (e) => debugPrint(e.toString()));
  }

  void viewCalls() {
    CallHistoryApi.viewCalls(newCalls);
  }

  Future<void> clearCallLog() async {
    DialogHelper.showAlertDialog(
      barrierDismissible: false,
      titleColor: errorColor,
      title: Text('clear_call_log'.tr),
      icon: const Icon(IconlyLight.delete, color: errorColor),
      content: Text('are_you_sure'.tr),
      actionText: 'clear'.tr.toUpperCase(),
      action: () {
        Get.back();
        CallHistoryApi.clearCallLog(calls);
      },
    );
  }
}
