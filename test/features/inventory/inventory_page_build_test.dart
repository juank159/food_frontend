import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:menu_plat/core/network/network_info.dart';
import 'package:menu_plat/core/services/local_cache_service.dart';
import 'package:menu_plat/core/services/offline_queue_service.dart';
import 'package:menu_plat/features/inventory/data/inventory_repository.dart';
import 'package:menu_plat/features/inventory/domain/entities/ingredient.dart';
import 'package:menu_plat/features/inventory/presentation/controllers/inventory_controller.dart';
import 'package:menu_plat/features/inventory/services/inventory_stock_service.dart';
import 'package:menu_plat/features/products/data/datasources/product_local_datasource.dart';

class _Offline implements NetworkInfo {
  @override
  Future<bool> get isConnected async => false;
}

/// Bug real reportado (modo debug): abrir Inventario lanzaba
/// "setState() or markNeedsBuild() called during build" — el controller se
/// crea DENTRO del build (`GetView.controller`) y su onInit actualizaba el
/// stock, que a su vez avisaba al contador de insumos bajos del menú.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('inv_build_test_');
    Hive.init(tmp.path);
    final queue = OfflineQueueService();
    await queue.init();
    final cache = LocalCacheService();
    await cache.init();
    await cache.saveList(InventoryRepository.ingredientsKey, [
      const Ingredient(id: 'a', name: 'Arepa', unit: IngredientUnit.unit, currentStock: 1, minStock: 5).toJson(),
    ]);
    final repo = InventoryRepository(dio: Dio(), networkInfo: _Offline(), cache: cache, queue: queue);
    GetIt.instance
      ..registerSingleton<InventoryRepository>(repo)
      ..registerSingleton<ProductLocalDataSource>(ProductLocalDataSourceImpl(cache: cache));
    Get.put(InventoryStockService(repository: repo));
  });

  tearDown(() async {
    Get.reset();
    await GetIt.instance.reset();
    await Hive.deleteFromDisk();
    await tmp.delete(recursive: true);
  });

  testWidgets('crear el controller de Inventario en pleno build no rompe a quien mira el stock', (tester) async {
    final stock = Get.find<InventoryStockService>();
    await tester.pumpWidget(MaterialApp(
      home: Column(
        children: [
          // Como el contador de "insumos bajos" del menú de inicio.
          Obx(() => Text('bajos ${stock.lowCount}')),
          // Como `GetView.controller`: crea el controller DURANTE el build.
          Builder(builder: (_) {
            Get.put(InventoryController());
            return const SizedBox();
          }),
        ],
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('bajos 1'), findsOneWidget);
  });
}
