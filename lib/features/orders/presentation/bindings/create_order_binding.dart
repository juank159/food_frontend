//lib/features/orders/presentation/bindings/create_order_binding.dart

import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../../products/domain/usecases/get_available_products_usecase.dart';
import '../../../products/domain/usecases/get_product_by_id_usecase.dart';
import '../../../products/domain/usecases/get_products_usecase.dart';
import '../../../products/presentation/controllers/products_controller.dart';
import '../../../tables/data/repositories/table_status_repository.dart';
import '../../../tables/presentation/controllers/table_status_controller.dart';
import '../../domain/usecases/create_order_usecase.dart';
import '../controllers/order_form_controller.dart';

/// Create Order Binding
/// Inyecta dependencias para el formulario de creación de órdenes
class CreateOrderBinding extends Bindings {
  @override
  void dependencies() {
    // Order Form Controller
    Get.lazyPut<OrderFormController>(
      () => OrderFormController(createOrderUseCase: sl<CreateOrderUseCase>()),
    );

    // Products Controller (si no está ya registrado)
    if (!Get.isRegistered<ProductsController>()) {
      Get.lazyPut<ProductsController>(
        () => ProductsController(
          getProductsUseCase: sl<GetProductsUseCase>(),
          getProductByIdUseCase: sl<GetProductByIdUseCase>(),
          getAvailableProductsUseCase: sl<GetAvailableProductsUseCase>(),
        ),
      );
    }

    // Table Status Controller (si no está ya registrado)
    if (!Get.isRegistered<TableStatusController>()) {
      Get.lazyPut<TableStatusController>(
        () => TableStatusController(repository: sl<TableStatusRepository>()),
      );
    }
  }
}
