import '../../../../core/services/local_cache_service.dart';
import '../../../../core/services/offline_queue_service.dart';
import '../../domain/entities/order.dart' as order_entity;
import '../models/order_model.dart';

abstract class OrderLocalDataSource {
  // Cache (para ver órdenes offline)
  Future<List<OrderModel>?> getCachedOrders();
  Future<void> cacheOrders(List<Map<String, dynamic>> rawJsonList);
  bool get hasFreshOrdersCache;

  /// Caché SIN importar su edad — para pintado "local-first" (ver
  /// `ProductLocalDataSource.peekCachedProducts`, mismo patrón). El
  /// caller es responsable de filtrar por fecha/estado si hace falta
  /// (esta caché no está scopeada a "hoy" — guarda el último fetch sin
  /// filtros, que en la práctica llega vía `loadUnpaidOrders`).
  Future<List<OrderModel>?> peekCachedOrders();

  /// Reemplaza (por id) la orden dentro de la caché de la lista — para
  /// que una mutación offline (cambiar estado, marcar item, agregar/
  /// quitar ítems) sobreviva un reinicio de la app mientras la
  /// mutación real sigue en cola. No falla si la orden no estaba
  /// cacheada (ej. se abrió por deep link) — simplemente no hace nada.
  Future<void> updateCachedOrder(order_entity.Order order);

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

  @override
  Future<List<OrderModel>?> peekCachedOrders() async {
    final raw = cache.getList(_cacheKey);
    if (raw == null) return null;
    return raw.map((json) => OrderModel.fromJson(json)).toList();
  }

  @override
  Future<void> updateCachedOrder(order_entity.Order order) async {
    final raw = cache.getList(_cacheKey);
    if (raw == null) return;
    final updatedJson = OrderModel.fromEntity(order).toJson();
    var found = false;
    final patched = raw.map((j) {
      if (j['id'] == order.id) {
        found = true;
        return updatedJson;
      }
      return j;
    }).toList();
    if (!found) return; // no estaba cacheada — nada que actualizar
    await cache.saveList(_cacheKey, patched);
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
