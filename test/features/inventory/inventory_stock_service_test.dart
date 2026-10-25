import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:menu_plat/core/network/network_info.dart';
import 'package:menu_plat/core/services/local_cache_service.dart';
import 'package:menu_plat/core/services/offline_queue_service.dart';
import 'package:menu_plat/features/inventory/data/inventory_repository.dart';
import 'package:menu_plat/features/inventory/domain/entities/ingredient.dart';
import 'package:menu_plat/features/inventory/domain/entities/recipe_line.dart';
import 'package:menu_plat/features/inventory/services/inventory_stock_service.dart';

class _Offline implements NetworkInfo {
  @override
  Future<bool> get isConnected async => false;
}

void main() {
  late Directory tmp;
  late InventoryStockService stock;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('inv_stock_test_');
    Hive.init(tmp.path);
    final queue = OfflineQueueService();
    await queue.init();
    final cache = LocalCacheService();
    await cache.init();
    await cache.saveList(InventoryRepository.ingredientsKey, [
      const Ingredient(id: 'arepa', name: 'Arepa tipo A', unit: IngredientUnit.unit, currentStock: 10, avgCost: 800)
          .toJson(),
      const Ingredient(id: 'pollo', name: 'Pollo', unit: IngredientUnit.g, currentStock: 350, avgCost: 20)
          .toJson(),
    ]);
    await cache.saveList(InventoryRepository.recipesKey, [
      const RecipeLine(ingredientId: 'arepa', quantity: 1, productId: 'p-pollo').toJson(),
      const RecipeLine(ingredientId: 'pollo', quantity: 100, productId: 'p-pollo').toJson(),
    ]);
    stock = InventoryStockService(
      repository: InventoryRepository(dio: Dio(), networkInfo: _Offline(), cache: cache, queue: queue),
    )..reloadLocal();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tmp.delete(recursive: true);
  });

  test('porciones = el insumo que menos alcanza (350 g de pollo / 100 g = 3)', () {
    expect(stock.portionsAvailable(productId: 'p-pollo'), 3);
  });

  test('descuenta lo que ya reserva el carrito', () {
    expect(
      stock.portionsAvailable(productId: 'p-pollo', reserved: {'pollo': 200, 'arepa': 2}),
      1,
    );
  });

  test('producto sin receta: null (no se controla)', () {
    expect(stock.portionsAvailable(productId: 'p-gaseosa'), isNull);
  });

  test('faltantes: avisa qué insumo queda negativo', () {
    final s = stock.shortagesFor({'pollo': 400, 'arepa': 4});
    expect(s.map((x) => x.ingredient.name), ['Pollo']);
    expect(s.single.after, -50);
  });

  test('costo de la receta con el costo promedio (1 × 800 + 100 × 20 = 2800)', () {
    expect(stock.recipeCost(productId: 'p-pollo'), 2800);
  });
}
