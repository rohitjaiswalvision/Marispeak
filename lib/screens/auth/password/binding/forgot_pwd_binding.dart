import 'package:get/get.dart';
import 'package:marispeaks/screens/auth/password/controller/forgot_pwd_controller.dart';

class ForgotPasswordBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ForgotPasswordController());
  }
}
