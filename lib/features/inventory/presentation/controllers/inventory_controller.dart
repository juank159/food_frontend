import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/usecases/adjust_stock_usecase.dart';
import '../../domain/usecases/get_inventory_usecase.dart';

/// Filtros de stock soportados por la pantalla de listado.
enum InventoryFilter {
  all,
  inStock,
  lowStock,
  outOfStock,
}

/// Inventory Controller
///
/// Sirve a las dos pantallas del módulo:
///
///   - `inventory_page`: lista filtrable con KPIs.
///   - `inventory_adjustment_page`: ajusta el stock de un item puntual.
///
/// Mantiene la lista en memoria y el filtro activo. El listado no se
/// recarga desde el backend al cambiar de filtro — se filtra localmente
/// (los items son pocos en restaurantes típicos y el endpoint no soporta
/// filtros granularres por estado de stock).
class InventoryController extends GetxController {
  final GetInventoryUseCase getInventoryUseCase;
  final AdjustStockUseCase adjustStockUseCase;

  InventoryController({
    required this.getInventoryUseCase,
    required this.adjustStockUseCase,
  });

  // Estado de la lista
  final RxList<InventoryItem> items = <InventoryItem>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final Rx<InventoryFilter> filter = InventoryFilter.all.obs;

  // Estado del formulario de ajuste
  final Rx<InventoryItem?> editingItem = Rx<InventoryItem?>(null);
  final RxBool isSaving = false.obs;
  final RxString saveError = ''.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = '';
    final result = await getInventoryUseCase();
    result.fold(
      (failure) => errorMessage.value = failure.message,
      (list) => items.value = list,
    );
    isLoading.value = false;
  }

  @override
  Future<void> refresh() => load();

  void setFilter(InventoryFilter f) => filter.value = f;

  /// Items pasados por el filtro activo. Sólo consideran productos que
  /// trackean inventario para los chips "low/out" — los que no, sólo se
  /// muestran en "Todos".
  List<InventoryItem> get filteredItems {
    switch (filter.value) {
      case InventoryFilter.all:
        return items;
      case InventoryFilter.inStock:
        return items.where((i) => i.isHealthyStock).toList();
      case InventoryFilter.lowStock:
        return items.where((i) => i.isLowStock).toList();
      case InventoryFilter.outOfStock:
        return items.where((i) => i.isOutOfStock).toList();
    }
  }

  // KPIs para el header
  int get totalCount => items.length;
  int get inStockCount => items.where((i) => i.isHealthyStock).length;
  int get lowStockCount => items.where((i) => i.isLowStock).length;
  int get outOfStockCount => items.where((i) => i.isOutOfStock).length;

  /// Marca un item para editar y dispara la navegación al form.
  void startAdjustment(InventoryItem item, {required VoidCallback onReady}) {
    editingItem.value = item;
    saveError.value = '';
    onReady();
  }

  /// Aplica el ajuste contra el backend. Devuelve `true` si tuvo éxito
  /// para que la página pueda hacer pop y mostrar un snackbar.
  Future<bool> submitAdjustment({
    required int newStock,
    int? minStockAlert,
    String? reason,
  }) async {
    final item = editingItem.value;
    if (item == null) return false;
    isSaving.value = true;
    saveError.value = '';
    final result = await adjustStockUseCase(
      productId: item.id,
      currentStock: newStock,
      minStockAlert: minStockAlert,
      reason: reason,
    );
    final ok = result.fold<bool>(
      (failure) {
        saveError.value = failure.message;
        return false;
      },
      (updated) {
        // Reemplazamos el item actualizado en la lista para que el
        // listado refleje el cambio sin esperar otro `load()`.
        final idx = items.indexWhere((i) => i.id == updated.id);
        if (idx >= 0) {
          items[idx] = updated;
        }
        editingItem.value = null;
        return true;
      },
    );
    isSaving.value = false;
    return ok;
  }
}
