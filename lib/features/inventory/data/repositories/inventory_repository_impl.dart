import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/services/local_cache_service.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/inventory_movement.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../datasources/inventory_remote_datasource.dart';
import '../models/inventory_item_model.dart';

/// Inventory Repository Implementation
class InventoryRepositoryImpl implements InventoryRepository {
  final InventoryRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;
  final LocalCacheService localCache;

  InventoryRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
    required this.localCache,
  });

  /// Local-first (mismo patrón que products/categories/etc.): si no
  /// hay red, cae a la caché sin importar su edad. `onlyTracked` es un
  /// filtro client-side (el backend no lo expone), así que aplica
  /// igual sobre el resultado cacheado.
  @override
  Future<Either<Failure, List<InventoryItem>>> getInventory({
    bool onlyTracked = false,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final models = await remoteDataSource.getInventory();
        await localCache.saveList(
          CacheKeys.inventory,
          models.map((m) => m.toJson()).toList(),
        );
        final entities = models.map((m) => m.toEntity()).toList();
        final result = onlyTracked
            ? entities.where((i) => i.trackInventory).toList()
            : entities;
        return Right(result);
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Inventory not found'));
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    }

    final raw = localCache.getList(CacheKeys.inventory);
    if (raw == null) return const Left(NetworkFailure());
    final entities =
        raw.map((j) => InventoryItemModel.fromJson(j).toEntity()).toList();
    final result = onlyTracked
        ? entities.where((i) => i.trackInventory).toList()
        : entities;
    return Right(result);
  }

  @override
  Future<Either<Failure, InventoryItem>> adjustStock({
    required String productId,
    required int currentStock,
    int? minStockAlert,
    String? reason,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      final model = await remoteDataSource.adjustStock(
        productId: productId,
        currentStock: currentStock,
        minStockAlert: minStockAlert,
        reason: reason,
      );
      return Right(model.toEntity());
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on NotFoundException {
      return const Left(NotFoundFailure('Product not found'));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<InventoryMovement>>> getInventoryHistory({
    required String productId,
    int limit = 50,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      final movements = await remoteDataSource.getInventoryHistory(
        productId: productId,
        limit: limit,
      );
      return Right(movements);
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on NotFoundException {
      return const Left(NotFoundFailure('Product not found'));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
