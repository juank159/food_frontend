import '../../../core/services/offline_queue_service.dart';
import '../domain/entities/ingredient.dart';
import '../domain/entities/ingredient_movement.dart';
import '../domain/entities/recipe_line.dart';

/// Rutas del backend que encola el inventario sin internet.
class InventoryPaths {
  static const ingredients = '/inventory/ingredients';
  static String ingredient(String id) => '/inventory/ingredients/$id';
  static const recipes = '/inventory/recipes';
  static const movements = '/inventory/movements';
  static const purchases = '/inventory/purchases';
  static const waste = '/inventory/waste';
  static const adjustments = '/inventory/adjustments';
  static const counts = '/inventory/counts';
}

double _num(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

double _round3(double v) => (v * 1000).round() / 1000;

/// Consumo de UNA unidad de un ítem vendido — misma fórmula que el
/// backend (`computeUnitConsumption`): receta del producto + de la
/// variante + Σ receta del extra × su cantidad por unidad.
Map<String, double> unitConsumption(
  List<RecipeLine> recipes, {
  String? productId,
  String? variantId,
  List<({String modifierId, int quantity})> modifiers = const [],
}) {
  final out = <String, double>{};
  void add(String id, double q) => out[id] = _round3((out[id] ?? 0) + q);
  for (final r in recipes) {
    if (r.quantity <= 0) continue;
    if (productId != null && r.productId == productId) {
      add(r.ingredientId, r.quantity);
    } else if (variantId != null && r.variantId == variantId) {
      add(r.ingredientId, r.quantity);
    } else if (r.modifierId != null) {
      for (final m in modifiers) {
        if (m.modifierId == r.modifierId) add(r.ingredientId, r.quantity * m.quantity);
      }
    }
  }
  return out;
}

/// Consumo total de una lista de ítems en formato de la API
/// (`items: [{product_id, variant_id, quantity, modifiers: [{modifier_id, quantity}]}]`).
Map<String, double> consumptionOfRawItems(
  List<RecipeLine> recipes,
  Iterable<dynamic> items,
) {
  final total = <String, double>{};
  for (final raw in items) {
    if (raw is! Map) continue;
    final qty = (raw['quantity'] as num?)?.toInt() ?? 1;
    final mods = <({String modifierId, int quantity})>[];
    final rawMods = raw['modifiers'];
    if (rawMods is List) {
      for (final m in rawMods) {
        if (m is Map && m['modifier_id'] is String) {
          mods.add((
            modifierId: m['modifier_id'] as String,
            quantity: (m['quantity'] as num?)?.toInt() ?? 1,
          ));
        }
      }
    }
    final unit = unitConsumption(
      recipes,
      productId: raw['product_id'] as String?,
      variantId: raw['variant_id'] as String?,
      modifiers: mods,
    );
    unit.forEach((id, q) => total[id] = _round3((total[id] ?? 0) + q * qty));
  }
  return total;
}

class InventoryOverlay {
  final List<Ingredient> ingredients;
  final List<RecipeLine> recipes;

  /// Movimientos todavía en la cola (para mostrarlos en el historial con
  /// "pendiente de sincronizar"). No incluye ventas: esas se ven en
  /// Órdenes, acá solo se descuentan.
  final List<IngredientMovement> pendingMovements;

  const InventoryOverlay({
    required this.ingredients,
    required this.recipes,
    required this.pendingMovements,
  });
}

/// Aplica a la copia local (`ingredients`/`recipes` del último fetch) lo
/// que todavía espera en la cola sin internet, para que la pantalla
/// muestre lo mismo que va a quedar al sincronizar:
///
///  - insumos creados / editados / borrados offline,
///  - recetas cambiadas offline,
///  - compras, mermas, ajustes y conteos,
///  - ventas hechas offline (órdenes nuevas e ítems agregados a tickets),
///    descontadas con la receta igual que en el backend.
///
/// Función pura: no toca la caché. Cuando la cola se vacía al
/// sincronizar, el próximo fetch trae la verdad del servidor.
InventoryOverlay applyPendingInventory({
  required List<Ingredient> ingredients,
  required List<RecipeLine> recipes,
  required Iterable<QueueEntry> queue,
}) {
  final byId = {for (final i in ingredients) i.id: i};
  final order = [for (final i in ingredients) i.id];
  var recipeList = List<RecipeLine>.from(recipes);
  final deltas = <String, double>{};
  final pending = <IngredientMovement>[];
  void addDelta(String id, double d) => deltas[id] = _round3((deltas[id] ?? 0) + d);
  var seq = 0;
  void addPending(String ingId, double delta, MovementReason reason, QueueEntry e,
      {String? reference, String? notes, double? unitCost}) {
    pending.add(IngredientMovement(
      id: 'pending_${seq++}',
      ingredientId: ingId,
      delta: delta,
      stockAfter: 0,
      reason: reason,
      unitCost: unitCost,
      reference: reference,
      notes: notes,
      createdAt: e.createdAt,
      pendingSync: true,
    ));
  }

  final entries = queue.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  // 1ª pasada: estructura (insumos y recetas) — las ventas de la 2ª
  // pasada necesitan las recetas ya actualizadas.
  for (final e in entries) {
    final p = e.payload;
    final path = p['path'] as String? ?? '';
    final method = p['method'] as String? ?? '';
    final body = p['body'];
    if (e.type == QueueOperationType.createEntity &&
        path == InventoryPaths.ingredients &&
        body is Map) {
      final id = p['local_id'] as String? ?? 'local_${e.id}';
      final name = (body['name'] as String? ?? '').trim();
      // El backend es idempotente por nombre: si ya existe, no se crea otro.
      if (byId.values.any((i) => i.name.toLowerCase() == name.toLowerCase())) continue;
      byId[id] = Ingredient(
        id: id,
        name: name,
        unit: IngredientUnit.fromCode(body['unit'] as String?),
        currentStock: 0,
        minStock: _num(body['min_stock']),
        avgCost: _num(body['unit_cost']),
        category: body['category'] as String?,
        sku: body['sku'] as String?,
      );
      order.add(id);
      final initial = _num(body['initial_stock']);
      if (initial != 0) {
        addDelta(id, initial);
        addPending(id, initial, MovementReason.initial, e);
      }
      continue;
    }
    if (e.type != QueueOperationType.genericMutation) continue;
    if (path.startsWith('${InventoryPaths.ingredients}/')) {
      final id = path.substring(InventoryPaths.ingredients.length + 1);
      final current = byId[id];
      if (current == null) continue;
      if (method == 'DELETE') {
        byId.remove(id);
        recipeList = recipeList.where((r) => r.ingredientId != id).toList();
      } else if (method == 'PATCH' && body is Map) {
        byId[id] = current.copyWith(
          name: body['name'] as String?,
          unit: body['unit'] != null ? IngredientUnit.fromCode(body['unit'] as String) : null,
          minStock: body['min_stock'] != null ? _num(body['min_stock']) : null,
          avgCost: body['avg_cost'] != null ? _num(body['avg_cost']) : null,
          category: body['category'] as String?,
          sku: body['sku'] as String?,
          isActive: body['is_active'] as bool?,
          notes: body['notes'] as String?,
        );
      }
    } else if (path == InventoryPaths.recipes && method == 'PUT' && body is Map) {
      final type = body['owner_type'] as String?;
      final ownerId = body['owner_id'] as String?;
      if (type == null || ownerId == null) continue;
      bool isOwner(RecipeLine r) =>
          (type == 'product' && r.productId == ownerId) ||
          (type == 'variant' && r.variantId == ownerId) ||
          (type == 'modifier' && r.modifierId == ownerId);
      recipeList = recipeList.where((r) => !isOwner(r)).toList();
      final items = body['items'];
      if (items is List) {
        for (final it in items) {
          if (it is! Map) continue;
          recipeList.add(RecipeLine(
            ingredientId: it['ingredient_id'] as String,
            quantity: _num(it['quantity']),
            productId: type == 'product' ? ownerId : null,
            variantId: type == 'variant' ? ownerId : null,
            modifierId: type == 'modifier' ? ownerId : null,
          ));
        }
      }
    }
  }

  // 2ª pasada: movimientos de stock.
  for (final e in entries) {
    final p = e.payload;
    if (e.type == QueueOperationType.createOrder) {
      final items = p['items'];
      if (items is List) {
        consumptionOfRawItems(recipeList, items).forEach((id, q) => addDelta(id, -q));
      }
      continue;
    }
    if (e.type != QueueOperationType.genericMutation) continue;
    final path = p['path'] as String? ?? '';
    final method = p['method'] as String? ?? '';
    final body = p['body'];
    if (body is! Map) continue;
    if (method == 'POST' && RegExp(r'^/orders/[^/]+/items$').hasMatch(path)) {
      consumptionOfRawItems(recipeList, [body]).forEach((id, q) => addDelta(id, -q));
      continue;
    }
    if (method != 'POST') continue;
    final lines = body['lines'];
    final notes = body['notes'] as String?;
    switch (path) {
      case InventoryPaths.purchases:
        if (lines is! List) break;
        final ref = [body['supplier'], body['invoice_number']]
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .join(' · ');
        for (final l in lines.whereType<Map>()) {
          final q = _num(l['quantity']);
          final id = l['ingredient_id'] as String;
          addDelta(id, q);
          final unitCost = l['unit_cost'] != null
              ? _num(l['unit_cost'])
              : (l['total_cost'] != null && q > 0 ? _num(l['total_cost']) / q : null);
          addPending(id, q, MovementReason.purchase, e,
              reference: ref.isEmpty ? null : ref, notes: notes, unitCost: unitCost);
        }
        break;
      case InventoryPaths.waste:
        if (lines is! List) break;
        for (final l in lines.whereType<Map>()) {
          final q = _num(l['quantity']);
          final id = l['ingredient_id'] as String;
          addDelta(id, -q);
          addPending(id, -q, MovementReason.waste, e,
              reference: l['reason'] as String?, notes: notes);
        }
        break;
      case InventoryPaths.adjustments:
        final id = body['ingredient_id'] as String?;
        if (id == null) break;
        final d = _num(body['delta']);
        addDelta(id, d);
        addPending(id, d, MovementReason.adjustment, e, notes: notes);
        break;
      case InventoryPaths.counts:
        if (lines is! List) break;
        for (final l in lines.whereType<Map>()) {
          final id = l['ingredient_id'] as String;
          final d = _round3(_num(l['counted']) - _num(l['expected']));
          addDelta(id, d);
          addPending(id, d, MovementReason.count, e,
              reference: 'Contado ${_num(l['counted'])}', notes: notes);
        }
        break;
    }
  }

  final result = <Ingredient>[];
  for (final id in order) {
    final ing = byId[id];
    if (ing == null) continue;
    final d = deltas[id] ?? 0;
    result.add(d == 0 ? ing : ing.copyWith(currentStock: _round3(ing.currentStock + d)));
  }
  return InventoryOverlay(
    ingredients: result,
    recipes: recipeList,
    pendingMovements: pending.reversed.toList(),
  );
}
