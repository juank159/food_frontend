import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:menu_plat/core/error/failures.dart';
import 'package:menu_plat/core/network/network_info.dart';
import 'package:menu_plat/core/services/local_cache_service.dart';
import 'package:menu_plat/core/services/offline_queue_service.dart';
import 'package:menu_plat/features/inventory/data/inventory_repository.dart';
import 'package:menu_plat/features/inventory/data/pending_inventory_overlay.dart';
import 'package:menu_plat/features/inventory/domain/entities/ingredient.dart';

class _Net implements NetworkInfo {
  bool connected = true;
  @override
  Future<bool> get isConnected async => connected;
}

/// Responde con lo que diga [handler] o simula que la red se cayó.
class _Adapter implements HttpClientAdapter {
  ({int status, Object body})? Function(RequestOptions o)? handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    requests.add(o);
    final r = handler?.call(o);
    if (r == null) {
      throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
    }
    return ResponseBody.fromString(jsonEncode(r.body), r.status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory tmp;
  late OfflineQueueService queue;
  late LocalCacheService cache;
  late _Net net;
  late _Adapter adapter;
  late InventoryRepository repo;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('inv_repo_test_');
    Hive.init(tmp.path);
    queue = OfflineQueueService();
    await queue.init();
    cache = LocalCacheService();
    await cache.init();
    net = _Net();
    adapter = _Adapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
    repo = InventoryRepository(dio: dio, networkInfo: net, cache: cache, queue: queue);
    await cache.saveList(InventoryRepository.ingredientsKey, [
      const Ingredient(id: 'arepa', name: 'Arepa tipo A', unit: IngredientUnit.unit, currentStock: 10)
          .toJson(),
    ]);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tmp.delete(recursive: true);
  });

  test('sin internet: la compra se encola (con client_request_id) y el stock ya la refleja', () async {
    net.connected = false;
    final r = await repo.purchase(lines: [(ingredientId: 'arepa', quantity: 20, unitCost: 800)]);

    expect(r.isRight(), isTrue);
    r.fold((_) {}, (res) => expect(res.synced, isFalse));
    final entry = queue.getAll().single;
    expect(entry.type, QueueOperationType.genericMutation);
    expect(entry.payload['path'], InventoryPaths.purchases);
    expect((entry.payload['body'] as Map)['client_request_id'], isNotEmpty);
    expect(repo.readLocal().ingredients.single.currentStock, 30);
    expect(adapter.requests, isEmpty);
  });

  test('con "internet" pero la red se cae al mandar: también se encola, no se pierde', () async {
    adapter.handler = (_) => null; // connectionError
    final r = await repo.waste(lines: [(ingredientId: 'arepa', quantity: 2, reason: 'Se quemó')]);

    expect(r.isRight(), isTrue);
    expect(queue.getAll(), hasLength(1));
    expect(repo.readLocal().ingredients.single.currentStock, 8);
  });

  test('error de validación del servidor (400): se informa y NO se encola', () async {
    adapter.handler = (_) => (status: 400, body: {'message': 'Uno de los insumos no existe'});
    final r = await repo.adjust(ingredientId: 'arepa', delta: 5, notes: 'x');

    expect(r.isLeft(), isTrue);
    r.fold((f) => expect(f, isA<ValidationFailure>()), (_) {});
    expect(queue.getAll(), isEmpty);
  });

  test('con internet: aplica en el servidor y actualiza la caché con lo que devuelve', () async {
    adapter.handler = (o) => (
          status: 201,
          body: {
            'duplicate': false,
            'ingredients': [
              {'id': 'arepa', 'name': 'Arepa tipo A', 'unit': 'unit', 'current_stock': '30.000', 'avg_cost': '850.0000'},
            ],
          },
        );
    final r = await repo.purchase(lines: [(ingredientId: 'arepa', quantity: 20, unitCost: 900)]);

    r.fold((_) => fail('no debería fallar'), (res) => expect(res.synced, isTrue));
    expect(queue.getAll(), isEmpty);
    final ing = repo.readLocal().ingredients.single;
    expect(ing.currentStock, 30);
    expect(ing.avgCost, 850);
  });

  test('crear insumo sin internet: queda con id local y aparece en la lista', () async {
    net.connected = false;
    final r = await repo.createIngredient(
      name: 'Queso',
      unit: IngredientUnit.g,
      initialStock: 2000,
    );

    r.fold((_) => fail('no debería fallar'), (ing) {
      expect(ing.isPendingSync, isTrue);
      expect(ing.currentStock, 2000);
    });
    expect(queue.getAll().single.type, QueueOperationType.createEntity);
    expect(repo.readLocal().ingredients.map((i) => i.name), containsAll(['Arepa tipo A', 'Queso']));
  });
}
