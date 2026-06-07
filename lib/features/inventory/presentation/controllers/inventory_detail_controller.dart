import 'package:get/get.dart';
import '../../../../core/routes/app_routes.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/inventory_movement.dart';
import '../../domain/repositories/inventory_repository.dart';
import 'inventory_controller.dart';

/// Estado de carga de la pantalla de detalle de inventario.
///
/// Mismo patrón que `CustomerDetailController`: un enum simple para que
/// la UI haga `switch` exhaustivo sin tener que cruzar varios `bool`.
enum InventoryDetailStatus { loading, loaded, error }

/// Inventory Detail Controller
///
/// Carga un `InventoryItem` puntual desde el repo. El backend de productos
/// expone `GET /products` (lista) y `GET /products/:id` (detalle), pero el
/// repositorio de inventario sólo expone `getInventory()`. Para no duplicar
/// código y mantener el módulo autosuficiente filtramos la lista por `id`
/// en el cliente — los catálogos de restaurantes son chicos y la lista ya
/// suele estar en cache de la pantalla anterior.
///
/// TODO(backend): cuando exista `GET /products/:id` mapeado a inventario o
/// se agregue `InventoryRepository.getById()`, reemplazar `_findItem()` por
/// la llamada directa para evitar el GET completo.
///
class InventoryDetailController extends GetxController {
  final InventoryRepository repository;

  InventoryDetailController({required this.repository});

  // ─────────────────────────── Estado ───────────────────────────

  final Rx<InventoryDetailStatus> status =
      InventoryDetailStatus.loading.obs;
  final RxString errorMessage = ''.obs;
  final Rxn<InventoryItem> item = Rxn<InventoryItem>();

  /// Histórico de movimientos del producto. Lo cargamos en paralelo
  /// con el item — si falla, mostramos lista vacía pero no rompemos la
  /// pantalla (el detalle del producto es lo importante).
  final RxList<InventoryMovement> history = <InventoryMovement>[].obs;
  final RxBool isLoadingHistory = false.obs;

  /// El ID se inyecta vía `Get.parameters['id']` en `onInit`.
  String? itemId;

  @override
  void onInit() {
    super.onInit();
    itemId = Get.parameters['id'];
    if (itemId == null || itemId!.isEmpty) {
      status.value = InventoryDetailStatus.error;
      errorMessage.value = 'No se pudo identificar el producto';
      return;
    }
    load();
  }

  // ─────────────────────────── Carga ───────────────────────────

  Future<void> load() async {
    if (itemId == null) return;
    status.value = InventoryDetailStatus.loading;
    errorMessage.value = '';

    final result = await repository.getInventory();
    result.fold(
      (failure) {
        status.value = InventoryDetailStatus.error;
        errorMessage.value = failure.message;
      },
      (list) {
        final found = _findItem(list, itemId!);
        if (found == null) {
          status.value = InventoryDetailStatus.error;
          errorMessage.value = 'No encontramos este producto en inventario.';
        } else {
          item.value = found;
          status.value = InventoryDetailStatus.loaded;
          // El histórico se carga en background — no bloquea la UI.
          loadHistory();
        }
      },
    );
  }

  /// Carga el histórico de movimientos del producto en background.
  /// Si falla, dejamos lista vacía y log silencioso — el detalle es
  /// la información primaria, el histórico es complemento.
  Future<void> loadHistory() async {
    if (itemId == null) return;
    isLoadingHistory.value = true;
    final result = await repository.getInventoryHistory(productId: itemId!);
    result.fold(
      (_) {
        // Silencioso: el placeholder de "sin movimientos" cubre el caso.
      },
      (movements) {
        history.value = movements;
      },
    );
    isLoadingHistory.value = false;
  }

  @override
  Future<void> refresh() => load();

  // ─────────────────────────── Acciones ───────────────────────────

  /// Navega al form de ajuste con el item actual. Reusa la instancia viva
  /// de `InventoryController` (registrada con `fenix: true`) para "armar"
  /// el item editable — la `InventoryAdjustmentPage` lee `editingItem` de
  /// ese controller para hidratar sus campos.
  Future<void> goToAdjustment() async {
    final current = item.value;
    if (current == null) return;
    // `fenix: true` garantiza que el InventoryController esté disponible
    // aunque la pantalla del listado se haya destruido.
    final inventoryCtrl = Get.find<InventoryController>();
    inventoryCtrl.startAdjustment(
      current,
      onReady: () => Get.toNamed(AppRoutes.inventoryAdjustment),
    );
    // Cuando volvemos del ajuste recargamos para reflejar el cambio.
    await load();
  }

  // ─────────────────────────── Derivados ───────────────────────────

  bool get isLoading => status.value == InventoryDetailStatus.loading;
  bool get hasError => status.value == InventoryDetailStatus.error;
  bool get isLoaded => status.value == InventoryDetailStatus.loaded;

  /// Ratio entre el stock actual y el umbral mínimo configurado. Devuelve
  /// `null` cuando no hay tracking, no hay umbral o el umbral es 0 (no
  /// tiene sentido un porcentaje contra cero).
  double? get stockRatio {
    final current = item.value;
    if (current == null) return null;
    if (!current.trackInventory) return null;
    final min = current.minStockAlert ?? 0;
    if (min <= 0) return null;
    final stock = current.currentStock ?? 0;
    return stock / min;
  }

  // ─────────────────────────── Helpers ───────────────────────────

  InventoryItem? _findItem(List<InventoryItem> list, String id) {
    for (final i in list) {
      if (i.id == id) return i;
    }
    return null;
  }
}
