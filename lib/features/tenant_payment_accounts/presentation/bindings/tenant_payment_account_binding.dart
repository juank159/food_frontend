import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/tenant_payment_account_usecases.dart';
import '../controllers/tenant_payment_account_controller.dart';

class TenantPaymentAccountBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TenantPaymentAccountController>(
      () => TenantPaymentAccountController(
        useCases: sl<TenantPaymentAccountUseCases>(),
      ),
    );
  }
}
