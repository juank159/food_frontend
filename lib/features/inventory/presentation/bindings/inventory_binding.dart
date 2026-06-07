import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/adjust_stock_usecase.dart';
import '../../domain/usecases/get_inventory_usecase.dart';
import '../controllers/inventory_controller.dart';

/// Inventory Binding
///
/// Registra el controller del módulo. Es `lazyPut` con `fenix: true`
/// para que el `inventory_adjustment_page` —que se abre desde la lista—
/// reuse la misma instancia (y vea los items ya cargados) y siga vivo
/// si Get destruye la lista detrás suyo durante la navegación push.
class InventoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InventoryController>(
      () => InventoryController(
        getInventoryUseCase: sl<GetInventoryUseCase>(),
        adjustStockUseCase: sl<AdjustStockUseCase>(),
      ),
      fenix: true,
    );
  }
}
