import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/modifier_enums.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_variant.dart';
import '../../domain/entities/modifier.dart';
import '../../domain/entities/modifier_group.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_remote_datasource.dart';

/// Product Repository Implementation
class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  ProductRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
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
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, List<Product>>> getAvailableProducts() async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getAvailableProducts();
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
}
