import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import '../../../products/data/datasources/product_local_datasource.dart';
import '../../../products/domain/entities/product.dart';
import '../../data/inventory_repository.dart';
import '../../domain/entities/ingredient.dart';
import '../../domain/entities/ingredient_movement.dart';
import '../../domain/entities/recipe_line.dart';
import '../../services/inventory_stock_service.dart';

enum IngredientFilter { all, low, out }

/// Fila de la pestaña "Costos": cuánto cuesta hacer cada cosa que se
/// vende y qué % del precio se lleva (food cost).
class FoodCostRow {
  final Product product;
  final String label;
  final double price;
  final double cost;
  final String? variantId;

  /// Algún insumo de la receta todavía no tiene costo cargado.
  final bool missingCosts;

  const FoodCostRow({
    required this.product,
    required this.label,
    required this.price,
    required this.cost,
    this.variantId,
    this.missingCosts = false,
  });

  double get pct => price > 0 ? cost / price * 100 : 0;
  double get margin => price - cost;
}

/// Pantalla de Inventario. Todo sale de `InventoryStockService` (local
/// + cola offline): abre instantáneo, con o sin internet.
class InventoryController extends GetxController {
  final InventoryStockService stock = Get.find<InventoryStockService>();
  final InventoryRepository _repo = GetIt.instance<InventoryRepository>();

  final RxInt tab = 0.obs;
  final Rx<IngredientFilter> filter = IngredientFilter.all.obs;
  final RxString search = ''.obs;

  final RxList<IngredientMovement> movements = <IngredientMovement>[].obs;
  final RxBool loadingMovements = false.obs;
  final Rxn<MovementReason> movementReason = Rxn<MovementReason>();

  final RxList<Product> products = <Product>[].obs;

  @override
  void onInit() {
    super.onInit();
    // refresh() ya relee la copia local (y no toca estado en pleno build:
    // este controller se crea DURANTE el build de InventoryPage).
    stock.refresh();
    _loadProducts();
    ever<int>(tab, (t) {
      if (t == 1 && movements.isEmpty) loadMovements();
      if (t == 2) _loadProducts();
    });
  }

  Future<void> refreshAll() async {
    await stock.refresh();
    if (tab.value == 1) await loadMovements();
    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    final cached = await GetIt.instance<ProductLocalDataSource>().peekCachedProducts();
    if (cached != null) {
      products.assignAll(cached.map((m) => m.toEntity()));
    }
  }

  Future<void> loadMovements() async {
    loadingMovements.value = true;
    final list = await _repo.movements(limit: 200);
    movements.assignAll(list);
    loadingMovements.value = false;
  }

  List<IngredientMovement> get visibleMovements {
    final r = movementReason.value;
    if (r == null) return movements;
    return movements.where((m) => m.reason == r).toList();
  }

  // ─────────────────────────── Insumos ───────────────────────────

  List<Ingredient> get visibleIngredients {
    final q = search.value.trim().toLowerCase();
    final list = stock.ingredients.where((i) {
      if (q.isNotEmpty &&
          !i.name.toLowerCase().contains(q) &&
          !(i.category ?? '').toLowerCase().contains(q)) {
        return false;
      }
      switch (filter.value) {
        case IngredientFilter.low:
          return i.isLow;
        case IngredientFilter.out:
          return i.isOut;
        case IngredientFilter.all:
          return true;
      }
    }).toList();
    // Lo urgente primero: agotados, luego bajos, luego el resto por nombre.
    int rank(Ingredient i) => i.isOut ? 0 : (i.isLow ? 1 : 2);
    list.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  double get inventoryValue =>
      stock.ingredients.fold(0.0, (s, i) => s + i.stockValue);

  // ─────────────────────────── Costos ───────────────────────────

  /// Productos (y variantes) con receta, del que más se lleva del precio
  /// al que menos — los de arriba son los que conviene revisar.
  List<FoodCostRow> get foodCostRows {
    final _ = stock.recipes.length + stock.ingredients.length;
    final rows = <FoodCostRow>[];
    for (final p in products) {
      final base = stock.recipeOf(RecipeOwnerType.product, p.id);
      if (p.variants.isEmpty) {
        if (base.isEmpty) continue;
        rows.add(_row(p, p.name, p.effectivePrice, base));
        continue;
      }
      for (final v in p.variants) {
        final lines = [...base, ...stock.recipeOf(RecipeOwnerType.variant, v.id)];
        if (lines.isEmpty) continue;
        rows.add(_row(p, '${p.name} · ${v.name}', p.effectivePrice + v.priceModifier, lines,
            variantId: v.id));
      }
    }
    rows.sort((a, b) => b.pct.compareTo(a.pct));
    return rows;
  }

  FoodCostRow _row(Product p, String label, double price, List<RecipeLine> lines,
      {String? variantId}) {
    var cost = 0.0;
    var missing = false;
    for (final l in lines) {
      final ing = stock.byId(l.ingredientId);
      if (ing == null || ing.avgCost <= 0) missing = true;
      cost += l.quantity * (ing?.avgCost ?? 0);
    }
    return FoodCostRow(
      product: p,
      label: label,
      price: price,
      cost: cost,
      variantId: variantId,
      missingCosts: missing,
    );
  }

  /// Productos que SE VENDEN pero no tienen receta (no descuentan nada).
  int get productsWithoutRecipe =>
      products.where((p) => !stock.hasRecipe(p.id) &&
          !p.variants.any((v) => stock.recipeOf(RecipeOwnerType.variant, v.id).isNotEmpty)).length;
}
