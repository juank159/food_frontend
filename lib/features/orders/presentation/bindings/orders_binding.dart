import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/create_order_usecase.dart';
import '../../domain/usecases/get_active_orders_usecase.dart';
import '../../domain/usecases/get_order_by_id_usecase.dart';
import '../../domain/usecases/get_orders_usecase.dart';
import '../../domain/usecases/update_order_status_usecase.dart';
import '../controllers/orders_controller.dart';

/// Orders Binding
/// Inyecta dependencias para el módulo de órdenes
class OrdersBinding extends Bindings {
  @override
  void dependencies() {
    // Controller
    Get.lazyPut<OrdersController>(
      () => OrdersController(
        getOrdersUseCase: sl<GetOrdersUseCase>(),
        getOrderByIdUseCase: sl<GetOrderByIdUseCase>(),
        getActiveOrdersUseCase: sl<GetActiveOrdersUseCase>(),
        createOrderUseCase: sl<CreateOrderUseCase>(),
        updateOrderStatusUseCase: sl<UpdateOrderStatusUseCase>(),
      ),
    );
  }
}
