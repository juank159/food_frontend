import '../../../../core/services/local_cache_service.dart';
import '../../../../core/services/offline_queue_service.dart';
import '../models/order_model.dart';

abstract class OrderLocalDataSource {
  // Cache (para ver órdenes offline)
  Future<List<OrderModel>?> getCachedOrders();
  Future<void> cacheOrders(List<Map<String, dynamic>> rawJsonList);
  bool get hasFreshOrdersCache;

  // Cola de salida (para crear órdenes offline)
  Future<void> enqueueCreateOrder(Map<String, dynamic> createOrderDto);
  List<QueueEntry> getPendingOrderCreations();
}

class OrderLocalDataSourceImpl implements OrderLocalDataSource {
  static const _cacheKey = 'orders_list';
  static const _cacheTtl = Duration(hours: 2);

  final LocalCacheService cache;
  final OfflineQueueService queue;

  OrderLocalDataSourceImpl({
    required this.cache,
    required this.queue,
  });

  // ─── CACHE ────────────────────────────────────────────────────────────────

  @override
  bool get hasFreshOrdersCache => !cache.isStale(_cacheKey, maxAge: _cacheTtl);

  @override
  Future<List<OrderModel>?> getCachedOrders() async {
    if (cache.isStale(_cacheKey, maxAge: _cacheTtl)) return null;
    final raw = cache.getList(_cacheKey);
    if (raw == null) return null;
    return raw.map((json) => OrderModel.fromJson(json)).toList();
  }

  @override
  Future<void> cacheOrders(List<Map<String, dynamic>> rawJsonList) async {
    await cache.saveList(_cacheKey, rawJsonList);
  }

  // ─── OUTBOX QUEUE ─────────────────────────────────────────────────────────

  @override
  Future<void> enqueueCreateOrder(Map<String, dynamic> createOrderDto) async {
    final entry = QueueEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: QueueOperationType.createOrder,
      payload: createOrderDto,
      createdAt: DateTime.now(),
    );
    await queue.enqueue(entry);
  }

  @override
  List<QueueEntry> getPendingOrderCreations() {
    return queue
        .getAll()
        .where((e) => e.type == QueueOperationType.createOrder)
        .toList();
  }
}
