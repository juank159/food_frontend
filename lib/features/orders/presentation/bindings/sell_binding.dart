import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';

import '../../../../core/di/injection_container.dart';
import '../../../payments/presentation/bindings/payment_binding.dart';
import '../../../products/domain/usecases/get_available_products_usecase.dart';
import '../../../products/domain/usecases/get_product_by_id_usecase.dart';
import '../../../products/domain/usecases/get_products_usecase.dart';
import '../../../products/presentation/controllers/products_controller.dart';
import '../../../tables/data/datasources/floor_plan_datasource.dart';
import '../../../tables/data/repositories/floor_plan_repository_impl.dart';
import '../../../tables/data/repositories/table_status_repository.dart';
import '../../../tables/domain/repositories/floor_plan_repository.dart';
import '../../../tables/presentation/controllers/table_status_controller.dart';
import '../../domain/usecases/create_order_usecase.dart';
import '../controllers/order_form_controller.dart';

/// Binding único para `SellPage`.
///
/// Reemplaza `QuickSaleBinding` y `CreateOrderBinding`. Registra todo
/// lo que necesita la pantalla:
///   - `OrderFormController` (cart, submit, modo actual).
///   - `ProductsController` (catálogo grid).
///   - `TableStatusController` + `FloorPlanRepository` (selector de
///     mesa dentro del `SellModeSheet`).
///   - `PaymentController` (cobro inmediato tras submit en modos
///     mostrador/takeaway/delivery).
class SellBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<OrderFormController>(
      () => OrderFormController(createOrderUseCase: sl<CreateOrderUseCase>()),
      fenix: false,
    );

    if (!Get.isRegistered<ProductsController>()) {
      Get.lazyPut<ProductsController>(
        () => ProductsController(
          getProductsUseCase: sl<GetProductsUseCase>(),
          getProductByIdUseCase: sl<GetProductByIdUseCase>(),
          getAvailableProductsUseCase: sl<GetAvailableProductsUseCase>(),
        ),
      );
    }

    // Necesario para el selector de mesa dentro del SellModeSheet.
    if (!Get.isRegistered<FloorPlanDataSource>()) {
      Get.lazyPut<FloorPlanDataSource>(
        () => FloorPlanDataSourceImpl(dio: sl<dio.Dio>()),
      );
    }
    if (!Get.isRegistered<FloorPlanRepository>()) {
      Get.lazyPut<FloorPlanRepository>(
        () => FloorPlanRepositoryImpl(
          dataSource: Get.find<FloorPlanDataSource>(),
        ),
      );
    }
    if (!Get.isRegistered<TableStatusController>()) {
      Get.lazyPut<TableStatusController>(
        () => TableStatusController(repository: sl<TableStatusRepository>()),
      );
    }

    // Cobro inmediato cuando el modo no es "agregar a cuenta abierta".
    PaymentBinding().dependencies();
  }
}
