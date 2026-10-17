import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/config/constants/modifier_enums.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/services/offline_queue_service.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_variant.dart';
import '../../domain/entities/modifier.dart';
import '../../domain/entities/modifier_group.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_local_datasource.dart';
import '../datasources/product_remote_datasource.dart';
import '../models/product_model.dart';

/// Product Repository Implementation
class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDataSource remoteDataSource;
  final ProductLocalDataSource localDataSource;
  final NetworkInfo networkInfo;
  final OfflineQueueService offlineQueue;

  ProductRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
    required this.offlineQueue,
  });

  @override
  Future<Either<Failure, List<Product>>> getProducts({
    String? categoryId,
    bool? isAvailable,
    String? search,
    List<String>? tags,
    int? page,
    int? limit,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getProducts(
          categoryId: categoryId,
          isAvailable: isAvailable,
          search: search,
          tags: tags,
          page: page,
          limit: limit,
        );
        // Cache the full unfiltered list only when no filters are applied,
        // so the cache represents the complete catalog.
        if (categoryId == null &&
            isAvailable == null &&
            search == null &&
            (tags == null || tags.isEmpty) &&
            page == null &&
            limit == null) {
          await localDataSource.cacheProducts(
            result.map((m) => m.toJson()).toList(),
          );
        }
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      final cached = await localDataSource.getCachedProducts();
      if (cached != null) return Right(cached.map((m) => m.toEntity()).toList());
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<List<Product>?> getCachedProductsPeek() async {
    final cached = await localDataSource.peekCachedProducts();
    if (cached == null) return null;
    return cached.map((m) => m.toEntity()).toList();
  }

  @override
  Future<Either<Failure, Product>> getProductById(String id) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getProductById(id);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Producto no encontrado'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      final cached = await localDataSource.getCachedProductById(id);
      if (cached != null) return Right(cached.toEntity());
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, List<Product>>> getAvailableProducts() async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getAvailableProducts();
        await localDataSource.cacheProducts(
          result.map((m) => m.toJson()).toList(),
        );
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      final cached = await localDataSource.getCachedProducts();
      if (cached != null) {
        final available = cached.where((m) => m.isAvailable).toList();
        return Right(available.map((m) => m.toEntity()).toList());
      }
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, List<Product>>> getLowStockProducts() async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getLowStockProducts();
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, List<Product>>> getProductsByCategory(
    String categoryId,
  ) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getProductsByCategory(categoryId);
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, Product>> getProductBySku(String sku) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getProductBySku(sku);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Producto no encontrado'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, Product>> createProduct({
    required String name,
    required double basePrice,
    required String sku,
    required String categoryId,
    String? description,
    double? cost,
    bool? requiresPreparation,
    int? preparationTime,
    String? imageUrl,
    List<String>? images,
    String? barcode,
    bool? isAvailable,
    bool? isFeatured,
    List<String>? tags,
    List<String>? allergens,
    Map<String, dynamic>? nutritionalInfo,
    bool? trackInventory,
    int? currentStock,
    int? minStockAlert,
    int? sortOrder,
    Map<String, dynamic>? metadata,
  }) async {
    // Crear un producto es seguro de encolar offline — ver
    // `QueueOperationType.createEntity`. El caso que esto habilita de
    // verdad: crear el producto Y agregarle sus extras ("Extras y
    // acompañantes") en la misma sesión offline — el grupo de
    // modifiers se crea referenciando este `local_id`, que se resuelve
    // solo al sincronizar.
    if (!await networkInfo.isConnected) {
      final localId = 'local_prod_${DateTime.now().microsecondsSinceEpoch}';
      final now = DateTime.now();
      final optimistic = Product(
        id: localId,
        name: name,
        description: description ?? '',
        basePrice: basePrice,
        cost: cost,
        requiresPreparation: requiresPreparation ?? true,
        preparationTime: preparationTime ?? 0,
        imageUrl: imageUrl,
        sku: sku,
        barcode: barcode,
        isAvailable: isAvailable ?? true,
        tags: tags ?? const [],
        allergens: allergens ?? const [],
        nutritionalInfo: nutritionalInfo,
        trackInventory: trackInventory ?? false,
        currentStock: currentStock,
        minStockAlert: minStockAlert,
        totalSold: 0,
        totalRevenue: 0,
        categoryId: categoryId,
        createdAt: now,
        updatedAt: now,
      );
      final offlineData = <String, dynamic>{
        'name': name,
        'base_price': basePrice,
        'sku': sku,
        'category_id': categoryId,
        if (description != null) 'description': description,
        if (cost != null) 'cost': cost,
        if (requiresPreparation != null)
          'requires_preparation': requiresPreparation,
        if (preparationTime != null) 'preparation_time': preparationTime,
        if (imageUrl != null) 'image_url': imageUrl,
        if (images != null && images.isNotEmpty) 'images': images,
        if (barcode != null) 'barcode': barcode,
        if (isAvailable != null) 'is_available': isAvailable,
        if (isFeatured != null) 'is_featured': isFeatured,
        if (tags != null && tags.isNotEmpty) 'tags': tags,
        if (allergens != null && allergens.isNotEmpty) 'allergens': allergens,
        if (nutritionalInfo != null) 'nutritional_info': nutritionalInfo,
        if (trackInventory != null) 'track_inventory': trackInventory,
        if (currentStock != null) 'current_stock': currentStock,
        if (minStockAlert != null) 'min_stock_alert': minStockAlert,
        if (sortOrder != null) 'sort_order': sortOrder,
        if (metadata != null) 'metadata': metadata,
      };
      await localDataSource.addCachedProduct(ProductModel.fromEntity(optimistic));
      await enqueueCreateEntity(
        offlineQueue,
        method: 'POST',
        path: ApiConstants.products,
        body: offlineData,
        localId: localId,
      );
      return Right(optimistic);
    }

    if (await networkInfo.isConnected) {
      try {
        final data = <String, dynamic>{
          'name': name,
          'base_price': basePrice,
          'sku': sku,
          'category_id': categoryId,
          if (description != null) 'description': description,
          if (cost != null) 'cost': cost,
          if (requiresPreparation != null)
            'requires_preparation': requiresPreparation,
          if (preparationTime != null) 'preparation_time': preparationTime,
          if (imageUrl != null) 'image_url': imageUrl,
          if (images != null && images.isNotEmpty) 'images': images,
          if (barcode != null) 'barcode': barcode,
          if (isAvailable != null) 'is_available': isAvailable,
          if (isFeatured != null) 'is_featured': isFeatured,
          if (tags != null && tags.isNotEmpty) 'tags': tags,
          if (allergens != null && allergens.isNotEmpty) 'allergens': allergens,
          if (nutritionalInfo != null) 'nutritional_info': nutritionalInfo,
          if (trackInventory != null) 'track_inventory': trackInventory,
          if (currentStock != null) 'current_stock': currentStock,
          if (minStockAlert != null) 'min_stock_alert': minStockAlert,
          if (sortOrder != null) 'sort_order': sortOrder,
          if (metadata != null) 'metadata': metadata,
        };

        final result = await remoteDataSource.createProduct(data);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, Product>> updateProduct({
    required String id,
    String? name,
    double? basePrice,
    String? sku,
    String? categoryId,
    String? description,
    double? cost,
    bool? requiresPreparation,
    int? preparationTime,
    String? imageUrl,
    List<String>? images,
    String? barcode,
    bool? isAvailable,
    bool? isFeatured,
    List<String>? tags,
    List<String>? allergens,
    Map<String, dynamic>? nutritionalInfo,
    bool? trackInventory,
    int? currentStock,
    int? minStockAlert,
    int? sortOrder,
    Map<String, dynamic>? metadata,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final data = <String, dynamic>{};
        if (name != null) data['name'] = name;
        if (basePrice != null) data['base_price'] = basePrice;
        if (sku != null) data['sku'] = sku;
        if (categoryId != null) data['category_id'] = categoryId;
        if (description != null) data['description'] = description;
        if (cost != null) data['cost'] = cost;
        if (requiresPreparation != null) {
          data['requires_preparation'] = requiresPreparation;
        }
        if (preparationTime != null) data['preparation_time'] = preparationTime;
        if (imageUrl != null) data['image_url'] = imageUrl;
        if (images != null) data['images'] = images;
        if (barcode != null) data['barcode'] = barcode;
        if (isAvailable != null) data['is_available'] = isAvailable;
        if (isFeatured != null) data['is_featured'] = isFeatured;
        if (tags != null) data['tags'] = tags;
        if (allergens != null) data['allergens'] = allergens;
        if (nutritionalInfo != null) data['nutritional_info'] = nutritionalInfo;
        if (trackInventory != null) data['track_inventory'] = trackInventory;
        if (currentStock != null) data['current_stock'] = currentStock;
        if (minStockAlert != null) data['min_stock_alert'] = minStockAlert;
        if (sortOrder != null) data['sort_order'] = sortOrder;
        if (metadata != null) data['metadata'] = metadata;

        final result = await remoteDataSource.updateProduct(id, data);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Producto no encontrado'));
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, Product>> updateStock({
    required String id,
    required int quantity,
    required String operation,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.updateStock(
          id: id,
          quantity: quantity,
          operation: operation,
        );
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Producto no encontrado'));
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> deleteProduct(String id) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.deleteProduct(id);
        return const Right(null);
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Producto no encontrado'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, ProductVariant>> createVariant({
    required String productId,
    required String name,
    required double priceModifier,
    String? description,
    bool? isDefault,
    int? sortOrder,
    bool? isAvailable,
    String? sku,
    int? scoopCount,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final data = <String, dynamic>{
          'product_id': productId,
          'name': name,
          'price_modifier': priceModifier,
          if (description != null) 'description': description,
          if (isDefault != null) 'is_default': isDefault,
          if (sortOrder != null) 'sort_order': sortOrder,
          if (isAvailable != null) 'is_available': isAvailable,
          if (sku != null) 'sku': sku,
          if (scoopCount != null) 'scoop_count': scoopCount,
        };

        final variantModel = await remoteDataSource.createVariant(data);
        return Right(variantModel.toEntity());
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, ProductVariant>> updateVariant({
    required String variantId,
    String? name,
    double? priceModifier,
    String? description,
    bool? isDefault,
    int? sortOrder,
    bool? isAvailable,
    String? sku,
    int? scoopCount,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final data = <String, dynamic>{
          if (name != null) 'name': name,
          if (priceModifier != null) 'price_modifier': priceModifier,
          if (description != null) 'description': description,
          if (isDefault != null) 'is_default': isDefault,
          if (sortOrder != null) 'sort_order': sortOrder,
          if (isAvailable != null) 'is_available': isAvailable,
          if (sku != null) 'sku': sku,
          if (scoopCount != null) 'scoop_count': scoopCount,
        };

        final variantModel = await remoteDataSource.updateVariant(variantId, data);
        return Right(variantModel.toEntity());
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Variante no encontrada'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> deleteVariant(String variantId) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.deleteVariant(variantId);
        return const Right(null);
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Variante no encontrada'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  // Modifier methods implementation
  @override
  Future<Either<Failure, List<Modifier>>> getModifiers({
    String? productId,
    String? categoryId,
    bool? isAvailable,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getModifiers(
          productId: productId,
          categoryId: categoryId,
          isAvailable: isAvailable,
        );
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, Modifier>> getModifierById(String id) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getModifierById(id);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Modificador no encontrado'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, Modifier>> createModifier({
    required String name,
    String? description,
    required ModifierType type,
    required double price,
    int? maxQuantity,
    bool? isAvailable,
    int? sortOrder,
    List<String>? productIds,
    List<String>? categoryIds,
  }) async {
    // Crear un modifier (ej. "Extra queso") es una entidad hoja —
    // segura de encolar offline igual que un gasto. Si referencia un
    // producto creado offline en `productIds`, se resuelve solo al
    // sincronizar (ver `QueueOperationType.createEntity`).
    if (!await networkInfo.isConnected) {
      final localId = 'local_mod_${DateTime.now().microsecondsSinceEpoch}';
      final optimistic = Modifier(
        id: localId,
        name: name,
        description: description,
        type: type,
        price: price,
        maxQuantity: maxQuantity,
        isAvailable: isAvailable ?? true,
        sortOrder: sortOrder ?? 0,
        appliesToProducts: productIds,
        appliesToCategories: categoryIds,
      );
      final body = <String, dynamic>{
        'name': name,
        'modifier_type': type.value,
        'price': price,
        if (description != null) 'description': description,
        if (maxQuantity != null) 'max_quantity': maxQuantity,
        if (isAvailable != null) 'is_available': isAvailable,
        if (sortOrder != null) 'sort_order': sortOrder,
        if (productIds != null || categoryIds != null)
          'applies_to': {
            if (productIds != null) 'product_ids': productIds,
            if (categoryIds != null) 'category_ids': categoryIds,
          },
      };
      await enqueueCreateEntity(
        offlineQueue,
        method: 'POST',
        path: ApiConstants.modifiers,
        body: body,
        localId: localId,
      );
      return Right(optimistic);
    }

    if (await networkInfo.isConnected) {
      try {
        final data = <String, dynamic>{
          'name': name,
          'modifier_type': type.value,
          'price': price,
          if (description != null) 'description': description,
          if (maxQuantity != null) 'max_quantity': maxQuantity,
          if (isAvailable != null) 'is_available': isAvailable,
          if (sortOrder != null) 'sort_order': sortOrder,
          if (productIds != null || categoryIds != null)
            'applies_to': {
              if (productIds != null) 'product_ids': productIds,
              if (categoryIds != null) 'category_ids': categoryIds,
            },
        };

        final modifierModel = await remoteDataSource.createModifier(data);
        return Right(modifierModel.toEntity());
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, Modifier>> updateModifier({
    required String id,
    String? name,
    String? description,
    ModifierType? type,
    double? price,
    int? maxQuantity,
    bool? isAvailable,
    int? sortOrder,
    List<String>? productIds,
    List<String>? categoryIds,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final data = <String, dynamic>{
          if (name != null) 'name': name,
          if (type != null) 'modifier_type': type.value,
          if (price != null) 'price': price,
          if (description != null) 'description': description,
          if (maxQuantity != null) 'max_quantity': maxQuantity,
          if (isAvailable != null) 'is_available': isAvailable,
          if (sortOrder != null) 'sort_order': sortOrder,
          if (productIds != null || categoryIds != null)
            'applies_to': {
              if (productIds != null) 'product_ids': productIds,
              if (categoryIds != null) 'category_ids': categoryIds,
            },
        };

        final modifierModel = await remoteDataSource.updateModifier(id, data);
        return Right(modifierModel.toEntity());
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Modificador no encontrado'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> deleteModifier(String id) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.deleteModifier(id);
        return const Right(null);
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Modificador no encontrado'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  // Modifier Group methods implementation
  @override
  Future<Either<Failure, List<ModifierGroup>>> getModifierGroups({
    String? productId,
    bool? isActive,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getModifierGroups(
          productId: productId,
          isActive: isActive,
        );
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, ModifierGroup>> createModifierGroup({
    required String name,
    required String productId,
    String? description,
    required SelectionType selectionType,
    int? minSelections,
    int? maxSelections,
    bool? isRequired,
    int? sortOrder,
    List<String>? modifierIds,
  }) async {
    // Crear un grupo de modifiers ("Extras y acompañantes") offline —
    // el caso real que el usuario pidió: crear el producto Y sus
    // extras sin internet. `productId` se resuelve solo al
    // sincronizar si el producto también se creó offline. También se
    // parcha la caché del producto para que el grupo aparezca de
    // inmediato al vender (ProductSelector) y sobreviva un reinicio.
    if (!await networkInfo.isConnected) {
      final localId = 'local_mg_${DateTime.now().microsecondsSinceEpoch}';
      final optimistic = ModifierGroup(
        id: localId,
        productId: productId,
        name: name,
        description: description,
        selectionType: selectionType,
        minSelections: minSelections ?? 0,
        maxSelections: maxSelections,
        isRequired: isRequired ?? false,
        sortOrder: sortOrder ?? 0,
      );
      final body = <String, dynamic>{
        'name': name,
        'product_id': productId,
        'selection_type': selectionType.value,
        if (description != null) 'description': description,
        if (minSelections != null) 'min_selections': minSelections,
        if (maxSelections != null) 'max_selections': maxSelections,
        if (isRequired != null) 'is_required': isRequired,
        if (sortOrder != null) 'sort_order': sortOrder,
        if (modifierIds != null) 'modifier_ids': modifierIds,
      };
      await enqueueCreateEntity(
        offlineQueue,
        method: 'POST',
        path: ApiConstants.modifierGroups,
        body: body,
        localId: localId,
      );
      final cachedProduct = await localDataSource.getCachedProductById(productId);
      if (cachedProduct != null) {
        final updated = cachedProduct.toEntity().copyWith(
              modifierGroups: [...cachedProduct.toEntity().modifierGroups, optimistic],
            );
        await localDataSource.updateCachedProduct(ProductModel.fromEntity(updated));
      }
      return Right(optimistic);
    }

    if (await networkInfo.isConnected) {
      try {
        final data = <String, dynamic>{
          'name': name,
          'product_id': productId,
          'selection_type': selectionType.value,
          if (description != null) 'description': description,
          if (minSelections != null) 'min_selections': minSelections,
          if (maxSelections != null) 'max_selections': maxSelections,
          if (isRequired != null) 'is_required': isRequired,
          if (sortOrder != null) 'sort_order': sortOrder,
          if (modifierIds != null) 'modifier_ids': modifierIds,
        };

        final groupModel = await remoteDataSource.createModifierGroup(data);
        return Right(groupModel.toEntity());
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, ModifierGroup>> updateModifierGroup({
    required String id,
    String? name,
    String? description,
    SelectionType? selectionType,
    int? minSelections,
    int? maxSelections,
    bool? isRequired,
    int? sortOrder,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final data = <String, dynamic>{
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          if (selectionType != null) 'selection_type': selectionType.value,
          if (minSelections != null) 'min_selections': minSelections,
          if (maxSelections != null) 'max_selections': maxSelections,
          if (isRequired != null) 'is_required': isRequired,
          if (sortOrder != null) 'sort_order': sortOrder,
        };

        final groupModel = await remoteDataSource.updateModifierGroup(id, data);
        return Right(groupModel.toEntity());
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Grupo de modificadores no encontrado'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> deleteModifierGroup(String id) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.deleteModifierGroup(id);
        return const Right(null);
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Grupo de modificadores no encontrado'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, ModifierGroup>> addModifiersToGroup({
    required String groupId,
    required List<String> modifierIds,
  }) async {
    // Asociar modifiers EXISTENTES a un grupo ya creado: mutación
    // sobre algo que ya tiene id real (o uno local que se resolverá
    // solo) — segura de encolar. No reconstruimos el detalle completo
    // de los modifiers nuevos acá (requeriría una caché de modifiers
    // que no existe todavía) — se conserva el grupo tal cual estaba
    // en caché para no mostrar datos a medias, y la asociación real
    // se refleja al volver la conexión y refrescar.
    if (!await networkInfo.isConnected) {
      await enqueueGenericMutation(
        offlineQueue,
        method: 'POST',
        path: ApiConstants.addModifiersToGroup(groupId),
        body: {'modifier_ids': modifierIds},
      );
      final cachedGroup = await _findCachedGroup(groupId);
      if (cachedGroup != null) return Right(cachedGroup);
      return Left(NotFoundFailure(
        'Grupo no encontrado en caché — se asignará al volver la conexión',
      ));
    }

    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.addModifiersToGroup(
          groupId,
          modifierIds,
        );
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(
            NotFoundFailure('Grupo de modificadores no encontrado'));
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> removeModifierFromGroup({
    required String groupId,
    required String modifierId,
  }) async {
    if (!await networkInfo.isConnected) {
      await enqueueGenericMutation(
        offlineQueue,
        method: 'DELETE',
        path: ApiConstants.removeModifierFromGroup(groupId, modifierId),
      );
      await _removeCachedGroupModifier(groupId, modifierId);
      return const Right(null);
    }

    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.removeModifierFromGroup(groupId, modifierId);
        return const Right(null);
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(
            NotFoundFailure('Modificador no encontrado en el grupo'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  /// Busca un grupo de modifiers por id entre TODOS los productos
  /// cacheados (un grupo no se cachea suelto, vive dentro de
  /// `Product.modifierGroups`). Usado por las mutaciones offline de
  /// grupos para devolver algo coherente sin tener que re-pedir al
  /// servidor.
  Future<ModifierGroup?> _findCachedGroup(String groupId) async {
    final products = await localDataSource.peekCachedProducts();
    if (products == null) return null;
    for (final p in products) {
      final entity = p.toEntity();
      for (final g in entity.modifierGroups) {
        if (g.id == groupId) return g;
      }
    }
    return null;
  }

  /// Quita [modifierId] del grupo [groupId] dentro de la caché de
  /// productos — contraparte de `_findCachedGroup` para la rama
  /// offline de `removeModifierFromGroup`.
  Future<void> _removeCachedGroupModifier(
    String groupId,
    String modifierId,
  ) async {
    final products = await localDataSource.peekCachedProducts();
    if (products == null) return;
    for (final p in products) {
      final entity = p.toEntity();
      final groupIdx = entity.modifierGroups.indexWhere((g) => g.id == groupId);
      if (groupIdx == -1) continue;
      final group = entity.modifierGroups[groupIdx];
      final updatedGroup = ModifierGroup(
        id: group.id,
        productId: group.productId,
        name: group.name,
        description: group.description,
        selectionType: group.selectionType,
        minSelections: group.minSelections,
        maxSelections: group.maxSelections,
        isRequired: group.isRequired,
        sortOrder: group.sortOrder,
        isActive: group.isActive,
        modifiers: group.modifiers.where((m) => m.id != modifierId).toList(),
      );
      final newGroups = [...entity.modifierGroups];
      newGroups[groupIdx] = updatedGroup;
      await localDataSource.updateCachedProduct(
        ProductModel.fromEntity(entity.copyWith(modifierGroups: newGroups)),
      );
      return;
    }
  }
}
