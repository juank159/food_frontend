import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/cash_session_usecases.dart';
import '../controllers/cash_session_controller.dart';

class CashSessionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CashSessionController>(
      () => CashSessionController(useCases: sl<CashSessionUseCases>()),
    );
  }
}
