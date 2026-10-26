import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/network_info.dart';
import '../../../core/services/local_cache_service.dart';
import '../../../core/services/offline_queue_service.dart';
import '../../../core/utils/api_response_utils.dart';
import 'suppliers_models.dart';

/// Resultado de una escritura: aplicada en el servidor, encolada sin
/// internet, o rechazada (con el mensaje para el usuario).
class SupplierWrite<T> {
  final bool synced;
  final T? value;
  final String? error;
  const SupplierWrite.ok(this.value) : synced = true, error = null;
  const SupplierWrite.queued() : synced = false, value = null, error = null;
  const SupplierWrite.failed(this.error) : synced = false, value = null;
  bool get failed => error != null;
}

/// Proveedores y compras, local-first: se lee de la copia del dispositivo
/// (con lo encolado sin internet encima) y la red solo la refresca. Lo
/// que se escribe sin internet queda en la cola y se manda solo; el
/// backend es idempotente (`client_request_id`, alta de proveedor por
/// nombre), así que un reintento no duplica nada.
class SuppliersRepository {
  static const suppliersKey = 'suppliers_list';
  static const purchasesKey = 'purchases_list';
  static const suggestionsKey = 'purchase_suggestions';

  static const paths = (suppliers: '/suppliers', purchases: '/purchases');

  final Dio dio;
  final NetworkInfo networkInfo;
  final LocalCacheService cache;
  final OfflineQueueService queue;

  SuppliersRepository({
    required this.dio,
    required this.networkInfo,
    required this.cache,
    required this.queue,
  });

  // ─────────────────────────────── Lectura ───────────────────────────────

  List<Supplier> readSuppliers() {
    final list = (cache.getList(suppliersKey) ?? const [])
        .map(Supplier.fromJson)
        .toList();
    // Proveedores creados sin internet (todavía en la cola).
    for (final e in queue.getAll()) {
      if (e.type != QueueOperationType.createEntity ||
          e.payload['path'] != paths.suppliers) {
        continue;
      }
      final body = e.payload['body'];
      if (body is! Map) continue;
      final name = (body['name'] as String? ?? '').trim();
      if (list.any((s) => s.name.toLowerCase() == name.toLowerCase())) continue;
      list.add(
        Supplier(
          id: e.payload['local_id'] as String,
          name: name,
          phone: body['phone'] as String?,
          paymentTermsDays: (body['payment_terms_days'] as num?)?.toInt() ?? 0,
          pendingSync: true,
        ),
      );
    }
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  List<Purchase> readPurchases() {
    final list = (cache.getList(purchasesKey) ?? const [])
        .map(Purchase.fromJson)
        .toList();
    final suppliers = {for (final s in readSuppliers()) s.id: s.name};
    // Compras registradas sin internet.
    for (final e in queue.getAll().map(queue.remapEntry)) {
      if (e.type != QueueOperationType.genericMutation) continue;
      if (e.payload['path'] != paths.purchases ||
          e.payload['method'] != 'POST') {
        continue;
      }
      final body = e.payload['body'];
      if (body is! Map) continue;
      final crid = body['client_request_id'] as String? ?? e.id;
      double total = 0;
      final lines = <PurchaseLine>[];
      for (final l in (body['lines'] as List? ?? const []).whereType<Map>()) {
        final q = (l['quantity'] as num?)?.toDouble() ?? 0;
        final unit = (l['unit_cost'] as num?)?.toDouble();
        final lineTotal =
            (l['total_cost'] as num?)?.toDouble() ?? (unit ?? 0) * q;
        total += lineTotal;
        lines.add(
          PurchaseLine(
            id: '',
            ingredientId: l['ingredient_id'] as String,
            quantityOrdered: q,
            quantityReceived: body['status'] == 'ordered' ? null : q,
            unitCost: unit ?? (q > 0 ? lineTotal / q : null),
            lineTotal: lineTotal,
          ),
        );
      }
      final paid =
          ((body['payment'] as Map?)?['amount'] as num?)?.toDouble() ?? 0;
      final ordered = body['status'] == 'ordered';
      list.insert(
        0,
        Purchase(
          id: 'pending_$crid',
          status: ordered ? 'ordered' : 'received',
          supplierId: body['supplier_id'] as String?,
          supplierName: suppliers[body['supplier_id']],
          invoiceNumber: body['invoice_number'] as String?,
          orderedAt: e.createdAt,
          receivedAt: ordered ? null : e.createdAt,
          total: total,
          paidAmount: paid,
          balance: ordered ? 0 : (total - paid).clamp(0, double.infinity),
          paymentStatus: paid <= 0
              ? 'pending'
              : (paid >= total ? 'paid' : 'partial'),
          lines: lines,
          pendingSync: true,
        ),
      );
    }
    return list;
  }

  List<PurchaseSuggestion> readSuggestions() =>
      (cache.getList(suggestionsKey) ?? const [])
          .map(PurchaseSuggestion.fromJson)
          .toList();

  // ─────────────────────────────── Refresco ───────────────────────────────

  /// Trae proveedores y compras del servidor. `false` si no hubo red.
  Future<bool> refresh() async {
    if (!await networkInfo.isConnected) return false;
    try {
      final results = await Future.wait([
        dio.get(paths.suppliers),
        dio.get(paths.purchases, queryParameters: {'limit': 300}),
      ]);
      await cache.saveList(
        suppliersKey,
        ApiResponseUtils.list(
          results[0],
        ).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
      );
      await cache.saveList(
        purchasesKey,
        ApiResponseUtils.list(
          results[1],
        ).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<PurchaseSuggestion>?> fetchSuggestions() async {
    try {
      final res = await dio.get('${paths.purchases}/suggestions');
      final obj = ApiResponseUtils.object(res);
      final items = (obj['items'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      await cache.saveList(suggestionsKey, items);
      return items.map(PurchaseSuggestion.fromJson).toList();
    } catch (_) {
      return null;
    }
  }

  Future<List<SupplierSpend>?> fetchSpend(DateTime from, DateTime to) async {
    try {
      final res = await dio.get(
        '${paths.suppliers}/reports/spend',
        queryParameters: {
          'from': from.toIso8601String(),
          'to': to.toIso8601String(),
        },
      );
      return ApiResponseUtils.list(res)
          .whereType<Map>()
          .map((e) => SupplierSpend.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<List<PricePoint>?> fetchPriceHistory(String ingredientId) async {
    try {
      final res = await dio.get(
        '${paths.purchases}/price-history/$ingredientId',
      );
      return ApiResponseUtils.list(res)
          .whereType<Map>()
          .map((e) => PricePoint.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Detalle de una compra (con pagos). Sin red, lo que haya en la copia local.
  Future<Purchase?> purchaseDetail(String id) async {
    if (!id.startsWith('pending_') && await networkInfo.isConnected) {
      try {
        final res = await dio.get('${paths.purchases}/$id');
        return Purchase.fromJson(ApiResponseUtils.object(res));
      } catch (_) {}
    }
    return readPurchases().where((p) => p.id == id).firstOrNull;
  }

  // ─────────────────────────────── Escritura ───────────────────────────────

  Future<SupplierWrite<Supplier>> createSupplier(
    Map<String, dynamic> body,
  ) async {
    if (await networkInfo.isConnected) {
      try {
        final res = await dio.post(paths.suppliers, data: body);
        await refresh();
        return SupplierWrite.ok(
          Supplier.fromJson(ApiResponseUtils.object(res)),
        );
      } on DioException catch (e) {
        if (!_isConnectionError(e)) return SupplierWrite.failed(_msg(e));
      }
    }
    final localId = 'local_sup_${DateTime.now().microsecondsSinceEpoch}';
    await enqueueCreateEntity(
      queue,
      method: 'POST',
      path: paths.suppliers,
      body: body,
      localId: localId,
    );
    return const SupplierWrite.queued();
  }

  Future<SupplierWrite<void>> updateSupplier(
    String id,
    Map<String, dynamic> body,
  ) => _write('PATCH', '${paths.suppliers}/$id', body);

  /// Compra recibida u orden de compra. [body] sin `client_request_id`:
  /// se agrega acá (el mismo para el intento con red y el encolado).
  Future<SupplierWrite<void>> createPurchase(Map<String, dynamic> body) =>
      _write('POST', paths.purchases, {
        ...body,
        'client_request_id': const Uuid().v4(),
      });

  Future<SupplierWrite<void>> receivePurchase(
    String id,
    Map<String, dynamic> body,
  ) => _write('POST', '${paths.purchases}/$id/receive', body);

  Future<SupplierWrite<void>> cancelPurchase(String id) =>
      _write('POST', '${paths.purchases}/$id/cancel', {});

  Future<SupplierWrite<void>> paySupplier(
    String supplierId,
    Map<String, dynamic> body,
  ) => _write('POST', '${paths.suppliers}/$supplierId/payments', {
    ...body,
    'client_request_id': const Uuid().v4(),
  });

  Future<SupplierWrite<void>> _write(
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    if (await networkInfo.isConnected) {
      try {
        await dio.request(
          path,
          data: body,
          options: Options(method: method),
        );
        await refresh();
        return const SupplierWrite.ok(null);
      } on DioException catch (e) {
        if (!_isConnectionError(e)) return SupplierWrite.failed(_msg(e));
      }
    }
    await enqueueGenericMutation(queue, method: method, path: path, body: body);
    return const SupplierWrite.queued();
  }

  String _msg(DioException e) =>
      ApiResponseUtils.errorMessage(e) ?? 'No se pudo guardar';

  bool _isConnectionError(DioException e) =>
      e.response == null &&
      (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.unknown);
}
