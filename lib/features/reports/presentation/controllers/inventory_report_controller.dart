import 'package:get/get.dart';
import '../../domain/entities/inventory_report.dart';
import '../../domain/usecases/get_inventory_report_usecase.dart';

/// Filtros internos del Reporte de Inventario.
///
///   * `all`   → todos los productos trackeados.
///   * `low`   → productos cuyo stock cayó por debajo del umbral.
///   * `out`   → productos sin stock.
enum InventoryFilter { all, low, out }

/// Inventory Report Controller
///
/// Reactivo. Mantiene el reporte y el filtro activo. El reporte es un
/// snapshot del estado vigente, así que no maneja rangos de fecha — sólo
/// un `refresh` para volver a pedir la lista al backend.
class InventoryReportController extends GetxController {
  final GetInventoryReportUseCase getInventoryReportUseCase;

  InventoryReportController({required this.getInventoryReportUseCase});

  /// Reporte completo (KPIs + lista trackeada).
  final Rx<InventoryReport> report = InventoryReport.empty().obs;

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  /// Filtro aplicado en la lista (no toca los KPIs del header).
  final Rx<InventoryFilter> filter = InventoryFilter.all.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = '';
    final result = await getInventoryReportUseCase();
    result.fold(
      (failure) => errorMessage.value = failure.message,
      (data) => report.value = data,
    );
    isLoading.value = false;
  }

  @override
  Future<void> refresh() => load();

  /// Cambia el filtro activo. No dispara llamada al backend porque la
  /// lista ya vino completa en `load()`.
  void selectFilter(InventoryFilter value) {
    filter.value = value;
  }

  /// Lista de productos a mostrar según el filtro vigente.
  List get visibleProducts {
    final r = report.value;
    switch (filter.value) {
      case InventoryFilter.low:
        return r.trackedProducts.where((p) => p.isLowStock).toList()
          ..sort((a, b) =>
              (a.currentStock ?? 0).compareTo(b.currentStock ?? 0));
      case InventoryFilter.out:
        return r.trackedProducts.where((p) => p.isOutOfStock).toList();
      case InventoryFilter.all:
        return r.sortedProducts;
    }
  }
}
