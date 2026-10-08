import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/splash_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    // AuthController se inicializa de forma permanente desde el inicio
    Get.put<AuthController>(
      AuthController(
        loginUseCase: di.sl(),
        registerUseCase: di.sl(),
        signUpBusinessUseCase: di.sl(),
        confirmSignupUseCase: di.sl(),
        resendSignupCodeUseCase: di.sl(),
        forgotPasswordUseCase: di.sl(),
        resetPasswordUseCase: di.sl(),
        logoutUseCase: di.sl(),
        getCurrentUserUseCase: di.sl(),
        updateProfileUseCase: di.sl(),
        changePasswordUseCase: di.sl(),
      ),
      permanent: true,
    );

    Get.put<SplashController>(
      SplashController(),
    );
  }
}
