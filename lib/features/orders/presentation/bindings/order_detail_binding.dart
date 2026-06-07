import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/get_order_by_id_usecase.dart';
import '../../domain/usecases/update_order_status_usecase.dart';
import '../../../payments/domain/usecases/create_payment_usecase.dart';
import '../../../payments/domain/usecases/get_payments_by_order_usecase.dart';
import '../../../payments/domain/usecases/process_order_payment_usecase.dart';
import '../../../payments/domain/usecases/process_split_payment_usecase.dart';
import '../../../payments/domain/usecases/refund_payment_usecase.dart';
import '../../../payments/presentation/controllers/payment_controller.dart';
import '../controllers/order_detail_controller.dart';

/// Order Detail Binding
/// Configura las dependencias para el detalle de orden con pagos
class OrderDetailBinding extends Bindings {
  @override
  void dependencies() {
    // Order Detail Controller
    Get.lazyPut<OrderDetailController>(
      () => OrderDetailController(
        getOrderByIdUseCase: sl<GetOrderByIdUseCase>(),
        updateOrderStatusUseCase: sl<UpdateOrderStatusUseCase>(),
      ),
    );

    // Payment Controller (si no está ya registrado)
    if (!Get.isRegistered<PaymentController>()) {
      Get.lazyPut<PaymentController>(
        () => PaymentController(
          processOrderPaymentUseCase: sl<ProcessOrderPaymentUseCase>(),
          processSplitPaymentUseCase: sl<ProcessSplitPaymentUseCase>(),
          getPaymentsByOrderUseCase: sl<GetPaymentsByOrderUseCase>(),
          refundPaymentUseCase: sl<RefundPaymentUseCase>(),
          createPaymentUseCase: sl<CreatePaymentUseCase>(),
        ),
      );
    }
  }
}
