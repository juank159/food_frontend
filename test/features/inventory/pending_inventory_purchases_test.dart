import 'package:flutter_test/flutter_test.dart';
import 'package:menu_plat/core/services/offline_queue_service.dart';
import 'package:menu_plat/features/inventory/data/pending_inventory_overlay.dart';
import 'package:menu_plat/features/inventory/domain/entities/ingredient.dart';

/// Compras (módulo de proveedores) hechas sin internet: el stock de la
/// pantalla de inventario tiene que reflejarlas antes de sincronizar.
const queso = Ingredient(id: 'queso', name: 'Queso', unit: IngredientUnit.g, currentStock: 1000);

var _seq = 0;
QueueEntry _post(String path, Map<String, dynamic> body) => QueueEntry(
      id: 'q${_seq++}',
      type: QueueOperationType.genericMutation,
      payload: {'method': 'POST', 'path': path, 'body': body},
      createdAt: DateTime(2026, 10, 26, 12, 0, _seq),
    );

double _stock(InventoryOverlay o) => o.ingredients.single.currentStock;

void main() {
  test('compra recibida sin internet suma stock', () {
    final o = applyPendingInventory(ingredients: [queso], recipes: const [], queue: [
      _post('/purchases', {
        'status': 'received',
        'lines': [
          {'ingredient_id': 'queso', 'quantity': 500, 'total_cost': 10000},
        ],
      }),
    ]);
    expect(_stock(o), 1500);
    expect(o.pendingMovements, hasLength(1));
  });

  test('una orden de compra (por llegar) NO mueve stock', () {
    final o = applyPendingInventory(ingredients: [queso], recipes: const [], queue: [
      _post('/purchases', {
        'status': 'ordered',
        'lines': [
          {'ingredient_id': 'queso', 'quantity': 500},
        ],
      }),
    ]);
    expect(_stock(o), 1000);
  });

  test('recibir una orden sin internet suma lo que llegó', () {
    final o = applyPendingInventory(
      ingredients: [queso],
      recipes: const [],
      purchaseLineIngredients: (id) => id == 'p1' ? {'l1': 'queso'} : const {},
      queue: [
        _post('/purchases/p1/receive', {
          'lines': [
            {'line_id': 'l1', 'quantity_received': 300},
          ],
        }),
      ],
    );
    expect(_stock(o), 1300);
  });

  test('la compra vieja de inventario (/inventory/purchases) sigue contando', () {
    final o = applyPendingInventory(ingredients: [queso], recipes: const [], queue: [
      _post(InventoryPaths.purchases, {
        'lines': [
          {'ingredient_id': 'queso', 'quantity': 200},
        ],
      }),
    ]);
    expect(_stock(o), 1200);
  });
}
