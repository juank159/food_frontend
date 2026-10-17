// lib features/tab_sessions/data/repositories/tab_session_repository_impl.dart
import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/services/offline_queue_service.dart';
import '../../domain/entities/tab_session.dart';
import '../../domain/repositories/tab_session_repository.dart';
import '../datasources/tab_session_local_datasource.dart';
import '../datasources/tab_session_remote_datasource.dart';
import '../models/tab_session_model.dart';

class TabSessionRepositoryImpl implements TabSessionRepository {
  final TabSessionRemoteDataSource remoteDataSource;
  final TabSessionLocalDataSource localDataSource;
  final NetworkInfo networkInfo;
  final OfflineQueueService offlineQueue;

  TabSessionRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
    required this.offlineQueue,
  });

  Future<Either<Failure, T>> _run<T>(Future<T> Function() action) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      return Right(await action());
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, TabSession>> open({
    String? tableElementId,
    String? tableId,
    String? customerId,
    int? partySize,
    String? notes,
  }) {
    return _run(() async {
      final model = await remoteDataSource.open({
        if (tableElementId != null) 'table_element_id': tableElementId,
        if (tableId != null) 'table_id': tableId,
        if (customerId != null) 'customer_id': customerId,
        if (partySize != null) 'party_size': partySize,
        if (notes != null) 'notes': notes,
      });
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, List<TabSession>>> findOpen() async {
    if (await networkInfo.isConnected) {
      try {
        final list = await remoteDataSource.findOpen();
        await localDataSource.cacheOpenTabs(
          list.map((m) => m.toJson()).toList(),
        );
        return Right(list.map((m) => m.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException catch (e) {
        return Left(NotFoundFailure(e.message));
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    }
    // Sin conexión: cae a la caché sin importar su edad — algo es
    // mejor que nada para ver qué cuentas están abiertas. Se le suma
    // lo que haya encolado offline por cuenta (ver `_withPendingOverlay`)
    // para que el listado de "cuentas abiertas" muestre el saldo real
    // (con lo recién despachado) y no el último conocido antes de
    // perder la señal.
    final cached = await localDataSource.getCachedOpenTabs();
    if (cached != null) {
      return Right(cached.map((m) => _withPendingOverlay(m.toEntity())).toList());
    }
    return const Left(NetworkFailure());
  }

  @override
  Future<List<TabSession>?> getCachedOpenTabsPeek() async {
    final cached = await localDataSource.peekCachedOpenTabs();
    if (cached == null) return null;
    return cached.map((m) => _withPendingOverlay(m.toEntity())).toList();
  }

  @override
  Future<Either<Failure, TabSession>> findOne(String id) async {
    // Abrir el detalle de una cuenta SIN internet: este es justo el
    // caso de negocio que el usuario pidió explícito — "si se va el
    // internet y tengo 20 clientes despachados, ¿cómo sé qué me debe
    // cada uno?". Antes esto fallaba directo (network-only) y la
    // pantalla de detalle no abría en absoluto.
    if (!await networkInfo.isConnected) {
      final cachedList = await localDataSource.peekCachedOpenTabs();
      TabSessionModel? cached;
      if (cachedList != null) {
        for (final m in cachedList) {
          if (m.id == id) {
            cached = m;
            break;
          }
        }
      }
      if (cached == null) return const Left(NetworkFailure());
      return Right(_withPendingOverlay(cached.toEntity()));
    }

    return _run(() async {
      final model = await remoteDataSource.findOne(id);
      return model.toEntity();
    });
  }

  /// Suma al saldo/total/cantidad de tickets de [entity] lo que haya
  /// encolado offline para esa cuenta (ver `_pendingOrdersTotalForTab`)
  /// — para que el número que ve el cajero incluya lo recién
  /// despachado sin esperar a sincronizar. No-op si no hay nada
  /// pendiente para esa cuenta.
  TabSession _withPendingOverlay(TabSession entity) {
    final pending = _pendingOrdersTotalForTab(entity.id);
    if (pending.amount == 0 && pending.count == 0) return entity;
    return TabSession(
      id: entity.id,
      tableId: entity.tableId,
      tableElementId: entity.tableElementId,
      tableName: entity.tableName,
      customerId: entity.customerId,
      customerName: entity.customerName,
      openedBy: entity.openedBy,
      openedByName: entity.openedByName,
      openedAt: entity.openedAt,
      closedBy: entity.closedBy,
      closedByName: entity.closedByName,
      closedAt: entity.closedAt,
      status: entity.status,
      partySize: entity.partySize,
      notes: entity.notes,
      totalOrders: entity.totalOrders + pending.count,
      subtotal: entity.subtotal + pending.amount,
      taxAmount: entity.taxAmount,
      discountAmount: entity.discountAmount,
      tipAmount: entity.tipAmount,
      deliveryFee: entity.deliveryFee,
      totalAmount: entity.totalAmount + pending.amount,
      paidAmount: entity.paidAmount,
      balance: entity.balance + pending.amount,
      orders: entity.orders,
    );
  }

  /// Suma aproximada (items + modifiers, sin impuestos exactos) de las
  /// órdenes encoladas offline (`QueueOperationType.createOrder`) que
  /// pertenecen a la cuenta [tabSessionId] y todavía no sincronizaron.
  ({double amount, int count}) _pendingOrdersTotalForTab(String tabSessionId) {
    double total = 0;
    var count = 0;
    for (final entry in offlineQueue.getAll()) {
      if (entry.type != QueueOperationType.createOrder) continue;
      if (entry.payload['tab_session_id'] != tabSessionId) continue;
      count++;
      final items = entry.payload['items'];
      if (items is! List) continue;
      for (final raw in items) {
        if (raw is! Map) continue;
        final unitPrice = (raw['unit_price'] as num?)?.toDouble() ?? 0;
        final quantity = (raw['quantity'] as num?)?.toInt() ?? 1;
        total += unitPrice * quantity;
        final modifiers = raw['modifiers'];
        if (modifiers is List) {
          for (final rawMod in modifiers) {
            if (rawMod is! Map) continue;
            final modPrice = (rawMod['price'] as num?)?.toDouble() ?? 0;
            final modQty = (rawMod['quantity'] as num?)?.toInt() ?? 1;
            total += modPrice * modQty * quantity;
          }
        }
      }
      final discount = (entry.payload['discount_amount'] as num?)?.toDouble() ?? 0;
      final deliveryFee = (entry.payload['delivery_fee'] as num?)?.toDouble() ?? 0;
      final tip = (entry.payload['tip_amount'] as num?)?.toDouble() ?? 0;
      total += deliveryFee + tip - discount;
    }
    return (amount: total, count: count);
  }

  @override
  Future<Either<Failure, TabSession>> update(
    String id, {
    String? customerName,
    String? notes,
    int? partySize,
  }) async {
    final body = <String, dynamic>{};
    if (customerName != null) body['customer_name'] = customerName;
    if (notes != null) body['notes'] = notes;
    if (partySize != null) body['party_size'] = partySize;

    // Renombrar la "etiqueta" de una cuenta (customerName/notes) es una
    // mutación sobre algo que YA existe con id real — segura de
    // encolar offline, igual que las mutaciones de OrderDetailController.
    // Esto es justo lo que el usuario pidió poder hacer sin internet.
    if (!await networkInfo.isConnected) {
      final cachedList = await localDataSource.peekCachedOpenTabs();
      TabSessionModel? cached;
      if (cachedList != null) {
        for (final m in cachedList) {
          if (m.id == id) {
            cached = m;
            break;
          }
        }
      }
      if (cached == null) return const Left(NetworkFailure());
      final optimistic = cached.toEntity().copyWithEditable(
            customerName: customerName,
            notes: notes,
            partySize: partySize,
          );
      await localDataSource.patchCachedOpenTab(
        id,
        customerName: customerName,
        notes: notes,
        partySize: partySize,
      );
      await enqueueGenericMutation(
        offlineQueue,
        method: 'PATCH',
        path: ApiConstants.tabSessionById(id),
        body: body,
      );
      return Right(optimistic);
    }

    return _run(() async {
      final model = await remoteDataSource.update(id, body);
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, TabSession>> close({
    required String id,
    bool force = false,
    String? notes,
  }) {
    return _run(() async {
      final model = await remoteDataSource.close(id, {
        'force': force,
        if (notes != null) 'notes': notes,
      });
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, void>> voidSession(String id) {
    return _run(() => remoteDataSource.voidSession(id));
  }
}
