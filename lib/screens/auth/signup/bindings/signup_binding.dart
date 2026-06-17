import 'package:get/get.dart';
import 'package:marispeaks/screens/auth/signup/controllers/signup_controller.dart';

class SignUpBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => SignUpController());
  }
}
