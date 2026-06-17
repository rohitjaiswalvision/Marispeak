import 'package:get/get.dart';
import 'package:marispeaks/screens/auth/signin/controller/phone_controller.dart';

class SignInBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => PhoneAuthController());
  }
}
