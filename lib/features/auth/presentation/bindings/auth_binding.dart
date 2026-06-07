import 'package:get/get.dart';
import '../controllers/auth_controller.dart';

/// Auth Binding - Manages dependency injection for Auth features
/// El AuthController ya está inicializado de forma permanente en SplashBinding
class AuthBinding extends Bindings {
  @override
  void dependencies() {
    // El AuthController ya está disponible de forma permanente
    // Solo verificamos que exista
    Get.find<AuthController>();
  }
}
