import 'package:flutter_test/flutter_test.dart';
import 'package:menu_plat/core/services/offline_queue_service.dart';
import 'package:menu_plat/features/inventory/data/pending_inventory_overlay.dart';
import 'package:menu_plat/features/inventory/domain/entities/ingredient.dart';
import 'package:menu_plat/features/inventory/domain/entities/ingredient_movement.dart';
import 'package:menu_plat/features/inventory/domain/entities/recipe_line.dart';

/// Caso real que originó el módulo: arepas. "Arepa tipo A" es el insumo
/// que compra el negocio; las presentaciones (queso, pollo) la usan.
const arepa = Ingredient(id: 'arepa', name: 'Arepa tipo A', unit: IngredientUnit.unit, currentStock: 100);
const queso = Ingredient(id: 'queso', name: 'Queso', unit: IngredientUnit.g, currentStock: 5000);

const recipes = [
  RecipeLine(ingredientId: 'arepa', quantity: 1, productId: 'p-queso'),
  RecipeLine(ingredientId: 'queso', quantity: 80, productId: 'p-queso'),
  RecipeLine(ingredientId: 'arepa', quantity: 1, variantId: 'v-doble'),
  RecipeLine(ingredientId: 'queso', quantity: 40, modifierId: 'm-queso'),
];

var _seq = 0;
QueueEntry _q(QueueOperationType type, Map<String, dynamic> payload) => QueueEntry(
      id: 'q${_seq++}',
      type: type,
      payload: payload,
      createdAt: DateTime(2026, 10, 24, 12, 0, _seq),
    );

QueueEntry _post(String path, Map<String, dynamic> body) =>
    _q(QueueOperationType.genericMutation, {'method': 'POST', 'path': path, 'body': body});

double _stock(InventoryOverlay o, String id) =>
    o.ingredients.firstWhere((i) => i.id == id).currentStock;

void main() {
  group('unitConsumption (misma fórmula que el backend)', () {
    test('producto + variante + extra × su cantidad', () {
      final c = unitConsumption(
        recipes,
        productId: 'p-queso',
        variantId: 'v-doble',
        modifiers: [(modifierId: 'm-queso', quantity: 2)],
      );
      expect(c, {'arepa': 2.0, 'queso': 160.0});
    });
  });

  group('applyPendingInventory (sin internet)', () {
    test('sin cola: devuelve la copia local tal cual', () {
      final o = applyPendingInventory(ingredients: [arepa], recipes: recipes, queue: const []);
      expect(_stock(o, 'arepa'), 100);
      expect(o.pendingMovements, isEmpty);
    });

    test('venta offline descuenta insumos según receta (2 arepas con queso doble + extra)', () {
      final o = applyPendingInventory(
        ingredients: [arepa, queso],
        recipes: recipes,
        queue: [
          _q(QueueOperationType.createOrder, {
            'items': [
              {
                'product_id': 'p-queso',
                'variant_id': 'v-doble',
                'quantity': 2,
                'modifiers': [
                  {'modifier_id': 'm-queso', 'quantity': 1},
                ],
              },
            ],
          }),
        ],
      );
      // por unidad: 2 arepas + 80 g + 40 g de queso; × 2 unidades
      expect(_stock(o, 'arepa'), 96);
      expect(_stock(o, 'queso'), 4760);
    });

    test('ítem agregado offline a un ticket existente también descuenta', () {
      final o = applyPendingInventory(
        ingredients: [arepa, queso],
        recipes: recipes,
        queue: [
          _post('/orders/ord-1/items', {'product_id': 'p-queso', 'quantity': 3}),
        ],
      );
      expect(_stock(o, 'arepa'), 97);
    });

    test('compra, merma, ajuste y conteo se reflejan y quedan como pendientes', () {
      final o = applyPendingInventory(
        ingredients: [arepa],
        recipes: recipes,
        queue: [
          _post(InventoryPaths.purchases, {
            'supplier': 'Don José',
            'lines': [
              {'ingredient_id': 'arepa', 'quantity': 50, 'unit_cost': 900},
            ],
          }),
          _post(InventoryPaths.waste, {
            'lines': [
              {'ingredient_id': 'arepa', 'quantity': 5, 'reason': 'Se quemó'},
            ],
          }),
          _post(InventoryPaths.adjustments, {'ingredient_id': 'arepa', 'delta': -2}),
          // contó 140 cuando el sistema decía 143 → −3
          _post(InventoryPaths.counts, {
            'lines': [
              {'ingredient_id': 'arepa', 'counted': 140, 'expected': 143},
            ],
          }),
        ],
      );
      expect(_stock(o, 'arepa'), 100 + 50 - 5 - 2 - 3);
      expect(
        o.pendingMovements.map((m) => m.reason),
        containsAll([
          MovementReason.purchase,
          MovementReason.waste,
          MovementReason.adjustment,
          MovementReason.count,
        ]),
      );
      final purchase = o.pendingMovements.firstWhere((m) => m.reason == MovementReason.purchase);
      expect(purchase.reference, 'Don José');
      expect(purchase.unitCost, 900);
      expect(o.pendingMovements.every((m) => m.pendingSync), isTrue);
    });

    test('insumo creado offline aparece con su stock inicial y se puede usar en una venta', () {
      final o = applyPendingInventory(
        ingredients: [arepa],
        recipes: recipes,
        queue: [
          _q(QueueOperationType.createEntity, {
            'method': 'POST',
            'path': InventoryPaths.ingredients,
            'local_id': 'local_ing_1',
            'body': {'name': 'Pollo', 'unit': 'g', 'initial_stock': 3000, 'unit_cost': 18},
          }),
          _q(QueueOperationType.genericMutation, {
            'method': 'PUT',
            'path': InventoryPaths.recipes,
            'body': {
              'owner_type': 'product',
              'owner_id': 'p-pollo',
              'items': [
                {'ingredient_id': 'arepa', 'quantity': 1},
                {'ingredient_id': 'local_ing_1', 'quantity': 100},
              ],
            },
          }),
          _q(QueueOperationType.createOrder, {
            'items': [
              {'product_id': 'p-pollo', 'quantity': 2},
            ],
          }),
        ],
      );
      final pollo = o.ingredients.firstWhere((i) => i.id == 'local_ing_1');
      expect(pollo.isPendingSync, isTrue);
      expect(pollo.unit, IngredientUnit.g);
      expect(pollo.currentStock, 3000 - 200);
      expect(_stock(o, 'arepa'), 98);
      expect(o.recipes.where((r) => r.productId == 'p-pollo'), hasLength(2));
    });

    test('alta offline con un nombre que ya existe no duplica (el backend es idempotente)', () {
      final o = applyPendingInventory(
        ingredients: [arepa],
        recipes: const [],
        queue: [
          _q(QueueOperationType.createEntity, {
            'method': 'POST',
            'path': InventoryPaths.ingredients,
            'local_id': 'local_ing_2',
            'body': {'name': 'arepa TIPO a', 'unit': 'unit'},
          }),
        ],
      );
      expect(o.ingredients, hasLength(1));
    });

    test('editar y borrar insumos offline', () {
      final o = applyPendingInventory(
        ingredients: [arepa, queso],
        recipes: recipes,
        queue: [
          _q(QueueOperationType.genericMutation, {
            'method': 'PATCH',
            'path': InventoryPaths.ingredient('arepa'),
            'body': {'min_stock': 30, 'name': 'Arepa A'},
          }),
          _q(QueueOperationType.genericMutation, {
            'method': 'DELETE',
            'path': InventoryPaths.ingredient('queso'),
          }),
        ],
      );
      expect(o.ingredients.single.name, 'Arepa A');
      expect(o.ingredients.single.minStock, 30);
      expect(o.recipes.any((r) => r.ingredientId == 'queso'), isFalse);
    });

    test('cambiar la receta offline afecta las ventas offline posteriores', () {
      final o = applyPendingInventory(
        ingredients: [arepa],
        recipes: recipes,
        queue: [
          _q(QueueOperationType.genericMutation, {
            'method': 'PUT',
            'path': InventoryPaths.recipes,
            'body': {
              'owner_type': 'product',
              'owner_id': 'p-queso',
              'items': [
                {'ingredient_id': 'arepa', 'quantity': 2},
              ],
            },
          }),
          _q(QueueOperationType.createOrder, {
            'items': [
              {'product_id': 'p-queso', 'quantity': 1},
            ],
          }),
        ],
      );
      expect(_stock(o, 'arepa'), 98);
    });

    test('vender y avisar: el stock puede quedar negativo', () {
      final o = applyPendingInventory(
        ingredients: [arepa.copyWith(currentStock: 1)],
        recipes: recipes,
        queue: [
          _q(QueueOperationType.createOrder, {
            'items': [
              {'product_id': 'p-queso', 'quantity': 3},
            ],
          }),
        ],
      );
      expect(_stock(o, 'arepa'), -2);
    });
  });

  group('IngredientUnit', () {
    test('convierte dentro de la misma familia', () {
      expect(IngredientUnit.g.convertFrom(2, IngredientUnit.kg), 2000);
      expect(IngredientUnit.kg.convertFrom(500, IngredientUnit.g), 0.5);
      expect(IngredientUnit.g.convertFrom(1, IngredientUnit.lb), 500);
      expect(IngredientUnit.ml.convertFrom(1.5, IngredientUnit.l), 1500);
    });

    test('no convierte entre familias distintas', () {
      expect(IngredientUnit.unit.compatible, [IngredientUnit.unit]);
      expect(IngredientUnit.g.convertFrom(3, IngredientUnit.ml), 3);
    });
  });
}
