import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../domain/usecases/adjust_stock_usecase.dart';
import '../../domain/usecases/get_inventory_usecase.dart';
import '../controllers/inventory_controller.dart';
import '../controllers/inventory_detail_controller.dart';

/// Inventory Detail Binding
///
/// Inyecta el `InventoryDetailController` con el repo de inventario.
/// También garantiza que `InventoryController` esté disponible — la
/// pantalla de detalle delega en él para "armar" el item editable cuando
/// el usuario toca "Ajustar" (mismo patrón que la pantalla de lista).
class InventoryDetailBinding extends Bindings {
  @override
  void dependencies() {
    // El controller de la lista puede no estar registrado si llegamos al
    // detalle vía deep-link sin haber pasado por el listado. Registramos
    // con fenix:true igual que `InventoryBinding` para reusar la misma
    // instancia cuando ya existe.
    if (!Get.isRegistered<InventoryController>()) {
      Get.lazyPut<InventoryController>(
        () => InventoryController(
          getInventoryUseCase: sl<GetInventoryUseCase>(),
          adjustStockUseCase: sl<AdjustStockUseCase>(),
        ),
        fenix: true,
      );
    }

    Get.lazyPut<InventoryDetailController>(
      () => InventoryDetailController(
        repository: sl<InventoryRepository>(),
      ),
    );
  }
}
