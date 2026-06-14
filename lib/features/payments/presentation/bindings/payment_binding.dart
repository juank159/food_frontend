import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/create_payment_usecase.dart';
import '../../domain/usecases/get_payments_by_order_usecase.dart';
import '../../domain/usecases/process_order_payment_usecase.dart';
import '../../domain/usecases/refund_payment_usecase.dart';
import '../controllers/payment_controller.dart';

/// Payment Binding
/// Configura las dependencias para el módulo de pagos
class PaymentBinding extends Bindings {
  @override
  void dependencies() {
    // Controller
    Get.lazyPut<PaymentController>(
      () => PaymentController(
        processOrderPaymentUseCase: sl<ProcessOrderPaymentUseCase>(),
        getPaymentsByOrderUseCase: sl<GetPaymentsByOrderUseCase>(),
        refundPaymentUseCase: sl<RefundPaymentUseCase>(),
        createPaymentUseCase: sl<CreatePaymentUseCase>(),
      ),
    );
  }
}
