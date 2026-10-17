import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/services/offline_queue_service.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../datasources/category_local_datasource.dart';
import '../datasources/category_remote_datasource.dart';
import '../models/category_model.dart';

/// Category Repository Implementation
/// Implementación concreta del repositorio de categorías con soporte offline-first.
class CategoryRepositoryImpl implements CategoryRepository {
  final CategoryRemoteDataSource remoteDataSource;
  final CategoryLocalDataSource localDataSource;
  final NetworkInfo networkInfo;
  final OfflineQueueService offlineQueue;

  CategoryRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
    required this.offlineQueue,
  });

  @override
  Future<Either<Failure, List<Category>>> getCategories({
    bool? isActive,
    String? search,
    int? page,
    int? limit,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getCategories(
          isActive: isActive,
          search: search,
          page: page,
          limit: limit,
        );
        // Cache only unfiltered full-list fetches so the cache stays coherent.
        if (isActive == null && search == null && page == null && limit == null) {
          await localDataSource.cacheCategories(
            result.map((m) => m.toJson()).toList(),
          );
        }
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Categories not found'));
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      final cached = await localDataSource.getCachedCategories();
      if (cached != null) {
        return Right(cached.map((m) => m.toEntity()).toList());
      }
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<List<Category>?> getCachedCategoriesPeek() async {
    final cached = await localDataSource.peekCachedCategories();
    if (cached == null) return null;
    return cached.map((m) => m.toEntity()).toList();
  }

  @override
  Future<Either<Failure, List<Category>>> getCategoryTree({
    bool? isActive,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getCategoryTree(
          isActive: isActive,
        );
        // Cache the tree when no filter is applied.
        if (isActive == null) {
          await localDataSource.cacheCategories(
            result.map((m) => m.toJson()).toList(),
          );
        }
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Category tree not found'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      final cached = await localDataSource.getCachedCategories();
      if (cached != null) {
        return Right(cached.map((m) => m.toEntity()).toList());
      }
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, List<Category>>> getActiveCategories() async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getActiveCategories();
        await localDataSource.cacheCategories(
          result.map((m) => m.toJson()).toList(),
        );
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Active categories not found'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      final cached = await localDataSource.getCachedCategories();
      if (cached != null) {
        // Filter locally to active-only, mirroring the remote call semantics.
        final active = cached.where((m) => m.isActive).toList();
        return Right(active.map((m) => m.toEntity()).toList());
      }
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, List<Category>>> getRootCategories({
    bool? isActive,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getRootCategories(
          isActive: isActive,
        );
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Root categories not found'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, Category>> getCategoryById(String id) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getCategoryById(id);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Category not found'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, List<Category>>> getSubcategories(
      String parentId) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getSubcategories(parentId);
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Subcategories not found'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, List<Category>>> searchCategories(String query) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getCategories(
          search: query,
        );
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Categories not found'));
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  // -------------------------------------------------------------------------
  // Write operations — always require connectivity
  // -------------------------------------------------------------------------

  @override
  Future<Either<Failure, Category>> createCategory({
    required String name,
    required String description,
    String? imageUrl,
    String? color,
    String? icon,
    bool isActive = true,
    int displayOrder = 0,
    String? parentId,
    bool printsKitchen = true,
    List<String>? quickNotes,
    String? flavorLabel,
  }) async {
    // Crear una categoría nueva es segura de encolar offline: es una
    // entidad "hoja" normalmente (nada depende de su id en ese mismo
    // instante) y, si el usuario crea un producto offline y lo asigna
    // a ESTA categoría en la misma sesión, el id local se resuelve
    // solo al sincronizar — ver `QueueOperationType.createEntity`.
    if (!await networkInfo.isConnected) {
      final localId = 'local_cat_${DateTime.now().microsecondsSinceEpoch}';
      final now = DateTime.now();
      final optimistic = Category(
        id: localId,
        name: name,
        description: description,
        imageUrl: imageUrl,
        color: color,
        icon: icon,
        isActive: isActive,
        displayOrder: displayOrder,
        parentId: parentId,
        printsKitchen: printsKitchen,
        quickNotes: quickNotes ?? const [],
        flavorLabel: flavorLabel,
        createdAt: now,
        updatedAt: now,
      );
      final body = <String, dynamic>{
        'name': name,
        'description': description,
        'is_active': isActive,
        'sort_order': displayOrder,
        'prints_kitchen': printsKitchen,
        'quick_notes': quickNotes ?? [],
        if (imageUrl != null) 'image_url': imageUrl,
        if (parentId != null) 'parent_category_id': parentId,
        if (flavorLabel != null && flavorLabel.isNotEmpty)
          'flavor_label': flavorLabel,
      };
      await localDataSource.addCachedCategory(CategoryModel.fromEntity(optimistic));
      await enqueueCreateEntity(
        offlineQueue,
        method: 'POST',
        path: ApiConstants.categories,
        body: body,
        localId: localId,
      );
      return Right(optimistic);
    }

    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.createCategory(
          name: name,
          description: description,
          imageUrl: imageUrl,
          color: color,
          icon: icon,
          isActive: isActive,
          displayOrder: displayOrder,
          parentId: parentId,
          printsKitchen: printsKitchen,
          quickNotes: quickNotes,
          flavorLabel: flavorLabel,
        );
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, Category>> updateCategory({
    required String id,
    String? name,
    String? description,
    String? imageUrl,
    String? color,
    String? icon,
    bool? isActive,
    int? displayOrder,
    String? parentId,
    bool? printsKitchen,
    List<String>? quickNotes,
    String? flavorLabel,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.updateCategory(
          id: id,
          name: name,
          description: description,
          imageUrl: imageUrl,
          color: color,
          icon: icon,
          isActive: isActive,
          displayOrder: displayOrder,
          parentId: parentId,
          printsKitchen: printsKitchen,
          quickNotes: quickNotes,
          flavorLabel: flavorLabel,
        );
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Category not found'));
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> deleteCategory(String id) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.deleteCategory(id);
        return const Right(null);
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Category not found'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }
}
