import 'package:flutter_test/flutter_test.dart';
import 'package:menu_plat/core/services/offline_queue_service.dart';
import 'package:menu_plat/features/inventory/data/pending_inventory_overlay.dart';
import 'package:menu_plat/features/inventory/domain/entities/ingredient.dart';
import 'package:menu_plat/features/inventory/domain/entities/ingredient_movement.dart';
import 'package:menu_plat/features/inventory/domain/entities/recipe_line.dart';

/// Multi-sucursal: el stock en pantalla es el de la sede del dispositivo.
/// Lo encolado sin internet guarda su sede (`QueueEntry.branchId`).
const harina = Ingredient(id: 'harina', name: 'Harina', unit: IngredientUnit.g, currentStock: 1000);
const recipes = [RecipeLine(ingredientId: 'harina', quantity: 100, productId: 'p-arepa')];

var _seq = 0;
QueueEntry _q(QueueOperationType type, Map<String, dynamic> payload, {String? branch}) => QueueEntry(
      id: 'q${_seq++}',
      type: type,
      payload: payload,
      createdAt: DateTime(2026, 10, 26, 12, 0, _seq),
      branchId: branch,
    );

double _stock(InventoryOverlay o) => o.ingredients.single.currentStock;

void main() {
  group('inventario pendiente por sede', () {
    test('una venta encolada en OTRA sede no descuenta del stock de esta', () {
      final o = applyPendingInventory(
        ingredients: [harina],
        recipes: recipes,
        branchId: 'centro',
        queue: [
          _q(QueueOperationType.createOrder, {
            'items': [
              {'product_id': 'p-arepa', 'quantity': 2},
            ],
          }, branch: 'norte'),
          _q(QueueOperationType.createOrder, {
            'items': [
              {'product_id': 'p-arepa', 'quantity': 1},
            ],
          }, branch: 'centro'),
        ],
      );
      expect(_stock(o), 900); // solo la de Centro
    });

    test('entradas viejas sin sede (antes de multi-sucursal) siguen contando', () {
      final o = applyPendingInventory(
        ingredients: [harina],
        recipes: recipes,
        branchId: 'centro',
        queue: [
          _q(QueueOperationType.createOrder, {
            'items': [
              {'product_id': 'p-arepa', 'quantity': 1},
            ],
          }),
        ],
      );
      expect(_stock(o), 900);
    });

    test('traslado pendiente: resta en el origen y suma en el destino', () {
      final transfer = _q(QueueOperationType.genericMutation, {
        'method': 'POST',
        'path': InventoryPaths.transfers,
        'body': {
          'from_branch_id': 'centro',
          'to_branch_id': 'norte',
          'lines': [
            {'ingredient_id': 'harina', 'quantity': 300},
          ],
        },
      }, branch: 'centro');
      final enCentro = applyPendingInventory(
          ingredients: [harina], recipes: recipes, branchId: 'centro', queue: [transfer]);
      final enNorte = applyPendingInventory(
          ingredients: [harina], recipes: recipes, branchId: 'norte', queue: [transfer]);
      final enSur = applyPendingInventory(
          ingredients: [harina], recipes: recipes, branchId: 'sur', queue: [transfer]);
      expect(_stock(enCentro), 700);
      expect(_stock(enNorte), 1300);
      expect(_stock(enSur), 1000);
      expect(enCentro.pendingMovements.single.reason, MovementReason.transfer);
    });
  });

  group('QueueEntry recuerda su sede', () {
    test('toJson/fromJson conserva branchId', () {
      final e = _q(QueueOperationType.createOrder, {'items': []}, branch: 'norte');
      final back = QueueEntry.fromJson(e.toJson());
      expect(back.branchId, 'norte');
    });

    test('remapear ids locales no pierde la sede', () {
      final e = _q(QueueOperationType.genericMutation, {'path': '/x/local_1'}, branch: 'norte');
      final copy = e.copyWith(payload: {'path': '/x/real'});
      expect(copy.branchId, 'norte');
      expect(copy.payload['path'], '/x/real');
    });

    test('entradas guardadas antes de multi-sucursal se leen sin sede', () {
      final json = _q(QueueOperationType.createOrder, {}).toJson()..remove('branchId');
      expect(QueueEntry.fromJson(json).branchId, isNull);
    });
  });
}
