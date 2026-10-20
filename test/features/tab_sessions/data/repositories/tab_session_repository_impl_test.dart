import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:menu_plat/core/network/network_info.dart';
import 'package:menu_plat/core/services/offline_queue_service.dart';
import 'package:menu_plat/features/tab_sessions/data/datasources/tab_session_local_datasource.dart';
import 'package:menu_plat/features/tab_sessions/data/datasources/tab_session_remote_datasource.dart';
import 'package:menu_plat/features/tab_sessions/data/models/tab_session_model.dart';
import 'package:menu_plat/features/tab_sessions/data/repositories/tab_session_repository_impl.dart';

class _FakeNetworkInfo implements NetworkInfo {
  bool connected = true;
  @override
  Future<bool> get isConnected async => connected;
}

class _FakeRemote implements TabSessionRemoteDataSource {
  @override
  Future<TabSessionModel> open(Map<String, dynamic> body) =>
      throw UnimplementedError();
  @override
  Future<List<TabSessionModel>> findOpen() => throw UnimplementedError();
  @override
  Future<TabSessionModel> findOne(String id) => throw UnimplementedError();
  @override
  Future<TabSessionModel> update(String id, Map<String, dynamic> body) =>
      throw UnimplementedError();
  @override
  Future<TabSessionModel> close(String id, Map<String, dynamic> body) =>
      throw UnimplementedError();
  @override
  Future<void> voidSession(String id) => throw UnimplementedError();
}

class _FakeLocal implements TabSessionLocalDataSource {
  List<TabSessionModel>? cached;
  final Map<String, Map<String, dynamic>> sessionDetailCache = {};

  @override
  Future<List<TabSessionModel>?> getCachedOpenTabs() async => cached;
  @override
  Future<List<TabSessionModel>?> peekCachedOpenTabs() async => cached;
  @override
  Future<void> cacheOpenTabs(List<Map<String, dynamic>> rawJsonList) async {}
  @override
  Future<void> patchCachedOpenTab(
    String id, {
    String? customerName,
    String? notes,
    int? partySize,
  }) async {}
  @override
  Future<void> cacheSessionDetail(
    String id,
    Map<String, dynamic> rawJson,
  ) async {
    sessionDetailCache[id] = rawJson;
  }
  @override
  Future<Map<String, dynamic>?> peekCachedSessionDetail(String id) async =>
      sessionDetailCache[id];
}

TabSessionModel _buildCachedSession({
  required String id,
  double subtotal = 10000,
  double totalAmount = 10000,
  double paidAmount = 0,
  double balance = 10000,
  int totalOrders = 1,
}) {
  return TabSessionModel.fromJson({
    'id': id,
    'table_id': null,
    'table_element_id': null,
    'table_name': 'Mesa 5',
    'customer_id': null,
    'customer_name': 'Juan',
    'opened_by': 'user-1',
    'opened_by_name': 'Cajero',
    'opened_at': DateTime.now().toIso8601String(),
    'closed_by': null,
    'closed_by_name': null,
    'closed_at': null,
    'status': 'open',
    'party_size': 2,
    'notes': null,
    'total_orders': totalOrders,
    'subtotal': subtotal,
    'tax_amount': 0,
    'discount_amount': 0,
    'tip_amount': 0,
    'delivery_fee': 0,
    'total_amount': totalAmount,
    'paid_amount': paidAmount,
    'balance': balance,
    'orders': [],
  });
}

void main() {
  late Directory tempDir;
  late OfflineQueueService queue;
  late _FakeNetworkInfo networkInfo;
  late _FakeLocal local;
  late TabSessionRepositoryImpl repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('offline_queue_test_');
    Hive.init(tempDir.path);
    queue = OfflineQueueService();
    await queue.init();
    networkInfo = _FakeNetworkInfo();
    local = _FakeLocal();
    repo = TabSessionRepositoryImpl(
      remoteDataSource: _FakeRemote(),
      localDataSource: local,
      networkInfo: networkInfo,
      offlineQueue: queue,
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  group('TabSessionRepositoryImpl.findOne — saldo offline (bug real a evitar)', () {
    test(
        'BUG REAL evitado: un ticket agregado offline a la cuenta SUMA al saldo mostrado, '
        'no se queda esperando a sincronizar para que el cajero lo vea', () async {
      networkInfo.connected = false;
      local.cached = [_buildCachedSession(id: 'tab-1', balance: 10000)];

      // Se agrega un ticket offline a esta cuenta: 2 x 5000 = 10000 de items.
      await queue.enqueue(QueueEntry(
        id: 'q1',
        type: QueueOperationType.createOrder,
        payload: {
          'tab_session_id': 'tab-1',
          'items': [
            {'product_id': 'p1', 'unit_price': 5000, 'quantity': 2},
          ],
        },
        createdAt: DateTime.now(),
      ));

      final result = await repo.findOne('tab-1');

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('no debería fallar'),
        (session) {
          expect(session.balance, 20000); // 10000 cacheado + 10000 del pending
          expect(session.totalOrders, 2); // 1 cacheado + 1 pending
        },
      );
    });

    test('sin ningún pending: devuelve el saldo cacheado tal cual', () async {
      networkInfo.connected = false;
      local.cached = [_buildCachedSession(id: 'tab-2', balance: 7000)];

      final result = await repo.findOne('tab-2');

      result.fold(
        (_) => fail('no debería fallar'),
        (session) => expect(session.balance, 7000),
      );
    });

    test('pending de OTRA cuenta no contamina el saldo de esta', () async {
      networkInfo.connected = false;
      local.cached = [_buildCachedSession(id: 'tab-3', balance: 5000)];

      await queue.enqueue(QueueEntry(
        id: 'q2',
        type: QueueOperationType.createOrder,
        payload: {
          'tab_session_id': 'tab-OTRA',
          'items': [
            {'product_id': 'p1', 'unit_price': 99999, 'quantity': 1},
          ],
        },
        createdAt: DateTime.now(),
      ));

      final result = await repo.findOne('tab-3');

      result.fold(
        (_) => fail('no debería fallar'),
        (session) => expect(session.balance, 5000),
      );
    });

    test('descuento/delivery/tip del pending también se reflejan en el saldo', () async {
      networkInfo.connected = false;
      local.cached = [_buildCachedSession(id: 'tab-4', balance: 0)];

      await queue.enqueue(QueueEntry(
        id: 'q3',
        type: QueueOperationType.createOrder,
        payload: {
          'tab_session_id': 'tab-4',
          'items': [
            {'product_id': 'p1', 'unit_price': 10000, 'quantity': 1},
          ],
          'discount_amount': 1000,
          'delivery_fee': 500,
          'tip_amount': 200,
        },
        createdAt: DateTime.now(),
      ));

      final result = await repo.findOne('tab-4');

      result.fold(
        (_) => fail('no debería fallar'),
        // 10000 - 1000 + 500 + 200 = 9700
        (session) => expect(session.balance, 9700),
      );
    });

    test('sin conexión y sin caché: falla (no hay nada que mostrar)', () async {
      networkInfo.connected = false;
      local.cached = null;

      final result = await repo.findOne('tab-inexistente');

      expect(result.isLeft(), true);
    });
  });
}
