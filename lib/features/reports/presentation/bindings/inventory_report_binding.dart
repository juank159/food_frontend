import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/get_inventory_report_usecase.dart';
import '../controllers/inventory_report_controller.dart';

/// Inventory Report Binding
///
/// Inyecta el `InventoryReportController` resolviendo su use case desde
/// el service locator (`GetIt`). Se registra como `lazyPut` para que la
/// instancia se cree sólo cuando se navega a la página.
class InventoryReportBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InventoryReportController>(
      () => InventoryReportController(
        getInventoryReportUseCase: sl<GetInventoryReportUseCase>(),
      ),
    );
  }
}
