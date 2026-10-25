import 'dart:async';
import 'package:get/get.dart';
import '../../../core/services/app_sync_service.dart';
import '../../../core/services/connectivity_service.dart';
import '../data/inventory_repository.dart';
import '../data/pending_inventory_overlay.dart';
import '../domain/entities/ingredient.dart';
import '../domain/entities/ingredient_movement.dart';
import '../domain/entities/recipe_line.dart';

/// Un insumo que no alcanza para lo que se quiere vender.
class StockShortage {
  final Ingredient ingredient;

  /// Cuánto quedaría (negativo) después de vender.
  final double after;
  const StockShortage(this.ingredient, this.after);
}

/// Fuente ÚNICA del stock de insumos en la app (pantalla de venta y de
/// inventario leen de acá). Vive todo el tiempo (`permanent`) para que
/// la venta lo tenga a mano sin esperar la red.
///
///  - Lee de la caché local con la cola offline aplicada encima → abre
///    instantáneo y, sin internet, ya refleja lo vendido/comprado.
///  - Refresca del servidor en segundo plano: al iniciar, al volver la
///    conexión, al terminar una sincronización y con el aviso en tiempo
///    real `inventory` (otra caja vendió / alguien registró una compra).
class InventoryStockService extends GetxService {
  final InventoryRepository repository;

  InventoryStockService({required this.repository});

  static InventoryStockService? get maybe =>
      Get.isRegistered<InventoryStockService>() ? Get.find<InventoryStockService>() : null;

  final RxList<Ingredient> ingredients = <Ingredient>[].obs;
  final RxList<RecipeLine> recipes = <RecipeLine>[].obs;
  final RxList<IngredientMovement> pendingMovements = <IngredientMovement>[].obs;

  /// Extras conocidos (para nombrarlos en "se usa en…" y costos).
  final RxMap<String, ({String name, double price})> modifiers =
      <String, ({String name, double price})>{}.obs;
  final RxBool isRefreshing = false.obs;
  final Rxn<DateTime> lastRefresh = Rxn<DateTime>();

  final List<Worker> _workers = [];
  Future<void>? _inFlight;

  /// Hay sesión iniciada: solo ahí se pide a la red (antes daría 401).
  bool _active = false;

  @override
  void onInit() {
    super.onInit();
    reloadLocal();
    if (Get.isRegistered<AppSyncService>()) {
      _workers.add(ever<bool>(AppSyncService.to.isSyncing, (syncing) {
        // Recién terminó de mandar la cola: lo pendiente ya está en el
        // servidor → traer la verdad.
        if (!syncing && _active) refresh();
      }));
    }
    if (Get.isRegistered<ConnectivityService>()) {
      _workers.add(ever<bool>(Get.find<ConnectivityService>().isOnline, (online) {
        if (online && _active) refresh();
      }));
    }
  }

  /// Tras login / sesión restaurada (`AuthController._startBackgroundServices`).
  void start() {
    _active = true;
    reloadLocal();
    refresh();
  }

  /// Al cerrar sesión: deja de pedir a la red y suelta lo que tenía en
  /// memoria (el próximo login refresca con los datos de ese negocio).
  void stop() {
    _active = false;
    ingredients.clear();
    recipes.clear();
    pendingMovements.clear();
    modifiers.clear();
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }

  /// Relee la caché + cola (sin red). Barato: llamarlo después de
  /// cualquier operación local.
  void reloadLocal() {
    final InventoryOverlay o = repository.readLocal();
    ingredients.assignAll(o.ingredients);
    recipes.assignAll(o.recipes);
    pendingMovements.assignAll(o.pendingMovements);
    modifiers.assignAll(repository.readModifiers());
  }

  /// Trae del servidor (si hay red) y relee. Coalesce llamadas
  /// simultáneas en una sola request.
  Future<void> refresh() {
    if (!_active) {
      reloadLocal();
      return Future.value();
    }
    // Si ya hay uno en curso, NO alcanza con sumarse a él: pudo haber
    // salido antes del cambio que motiva este pedido (bug real: al volver
    // la red, "hay red" y "terminó el sync" piden casi a la vez; el
    // segundo se colgaba del primero — que salió ANTES de mandar la cola
    // — y la pantalla quedaba con el stock viejo). Se marca y se repite
    // una vez más al terminar.
    if (_inFlight != null) {
      _again = true;
      return _inFlight!;
    }
    return _inFlight = () async {
      isRefreshing.value = true;
      try {
        do {
          _again = false;
          final r = await repository.refresh();
          if (r.isRight()) lastRefresh.value = DateTime.now();
        } while (_again);
      } finally {
        reloadLocal();
        isRefreshing.value = false;
        _inFlight = null;
      }
    }();
  }

  bool _again = false;

  Ingredient? byId(String id) => ingredients.firstWhereOrNull((i) => i.id == id);

  int get lowCount => ingredients.where((i) => i.isActive && i.isLow).length;
  int get outCount => ingredients.where((i) => i.isActive && i.isOut).length;

  // ─────────────────────────── Recetas ───────────────────────────

  List<RecipeLine> recipeOf(RecipeOwnerType type, String ownerId) => recipes
      .where((r) => r.ownerType == type && r.ownerId == ownerId)
      .toList();

  bool hasRecipe(String productId) =>
      recipes.any((r) => r.productId == productId);

  /// Recetas donde aparece un insumo (para "se usa en…").
  List<RecipeLine> usagesOf(String ingredientId) =>
      recipes.where((r) => r.ingredientId == ingredientId).toList();

  /// Costo de UNA unidad según su receta (producto + variante opcional),
  /// con el costo promedio de cada insumo. `null` si no tiene receta.
  double? recipeCost({required String productId, String? variantId}) {
    final c = unitConsumption(recipes, productId: productId, variantId: variantId);
    if (c.isEmpty) return null;
    var total = 0.0;
    c.forEach((id, q) => total += q * (byId(id)?.avgCost ?? 0));
    return total;
  }

  double ownerCost(RecipeOwnerType type, String ownerId) {
    var total = 0.0;
    for (final r in recipeOf(type, ownerId)) {
      total += r.quantity * (byId(r.ingredientId)?.avgCost ?? 0);
    }
    return total;
  }

  // ─────────────────────── Disponibilidad ───────────────────────

  /// Cuántas unidades se pueden vender todavía con el stock actual,
  /// descontando lo que ya consume [reserved] (ej. el carrito). `null`
  /// si el ítem no tiene receta (no se controla).
  int? portionsAvailable({
    required String productId,
    String? variantId,
    List<({String modifierId, int quantity})> modifiers = const [],
    Map<String, double> reserved = const {},
  }) {
    final unit = unitConsumption(
      recipes,
      productId: productId,
      variantId: variantId,
      modifiers: modifiers,
    );
    if (unit.isEmpty) return null;
    int? min;
    unit.forEach((id, q) {
      final ing = byId(id);
      if (ing == null || q <= 0) return;
      final left = ing.currentStock - (reserved[id] ?? 0);
      final n = left <= 0 ? 0 : (left / q + 1e-9).floor();
      if (min == null || n < min!) min = n;
    });
    return min;
  }

  /// Insumos que quedarían en negativo si se vende [consumption].
  List<StockShortage> shortagesFor(Map<String, double> consumption) {
    final out = <StockShortage>[];
    consumption.forEach((id, q) {
      final ing = byId(id);
      if (ing == null) return;
      final after = ing.currentStock - q;
      if (after < -1e-9) out.add(StockShortage(ing, after));
    });
    return out;
  }
}
