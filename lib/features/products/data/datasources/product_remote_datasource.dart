import 'package:dio/dio.dart';
import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../models/product_model.dart';
import '../models/product_variant_model.dart';
import '../models/modifier_model.dart';
import '../models/modifier_group_model.dart';

/// Product Remote Data Source Interface
abstract class ProductRemoteDataSource {
  Future<List<ProductModel>> getProducts({
    String? categoryId,
    bool? isAvailable,
    String? search,
    List<String>? tags,
    int? page,
    int? limit,
  });

  Future<ProductModel> getProductById(String id);

  Future<List<ProductModel>> getAvailableProducts();

  Future<List<ProductModel>> getLowStockProducts();

  Future<List<ProductModel>> getProductsByCategory(String categoryId);

  Future<ProductModel> getProductBySku(String sku);

  Future<ProductModel> createProduct(Map<String, dynamic> data);

  Future<ProductModel> updateProduct(String id, Map<String, dynamic> data);

  Future<ProductModel> updateStock({
    required String id,
    required int quantity,
    required String operation,
  });

  Future<void> deleteProduct(String id);

  // Variant methods
  Future<ProductVariantModel> createVariant(Map<String, dynamic> data);

  Future<ProductVariantModel> updateVariant(String id, Map<String, dynamic> data);

  Future<void> deleteVariant(String id);

  // Modifier methods
  Future<List<ModifierModel>> getModifiers({
    String? productId,
    String? categoryId,
    bool? isAvailable,
  });

  Future<ModifierModel> getModifierById(String id);

  Future<ModifierModel> createModifier(Map<String, dynamic> data);

  Future<ModifierModel> updateModifier(String id, Map<String, dynamic> data);

  Future<void> deleteModifier(String id);

  // Modifier Group methods
  Future<List<ModifierGroupModel>> getModifierGroups({
    String? productId,
    bool? isActive,
  });

  Future<ModifierGroupModel> createModifierGroup(Map<String, dynamic> data);

  Future<ModifierGroupModel> updateModifierGroup(
      String id, Map<String, dynamic> data);

  Future<void> deleteModifierGroup(String id);

  Future<ModifierGroupModel> addModifiersToGroup(
    String groupId,
    List<String> modifierIds,
  );

  Future<void> removeModifierFromGroup(String groupId, String modifierId);
}

/// Product Remote Data Source Implementation
class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  final Dio dio;

  ProductRemoteDataSourceImpl({required this.dio});

  @override
  Future<List<ProductModel>> getProducts({
    String? categoryId,
    bool? isAvailable,
    String? search,
    List<String>? tags,
    int? page,
    int? limit,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (categoryId != null) queryParams['category_id'] = categoryId;
      if (isAvailable != null) queryParams['is_available'] = isAvailable;
      if (search != null) queryParams['search'] = search;
      if (tags != null && tags.isNotEmpty) queryParams['tags'] = tags.join(',');
      if (page != null) queryParams['page'] = page;
      if (limit != null) queryParams['limit'] = limit;

      final response = await dio.get(
        ApiConstants.products,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        // API returns array directly, not wrapped in {data: []}
        final List<dynamic> data;
        if (response.data is List) {
          data = response.data as List<dynamic>;
        } else if (response.data is Map && response.data['data'] != null) {
          data = response.data['data'] as List<dynamic>;
        } else {
          throw ServerException('Unexpected response format', response.statusCode);
        }
        return data.map((json) => ProductModel.fromJson(json)).toList();
      } else {
        throw ServerException('Failed to get products', response.statusCode);
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<ProductModel> getProductById(String id) async {
    try {
      final response = await dio.get(ApiConstants.productById(id));

      if (response.statusCode == 200) {
        return ProductModel.fromJson(response.data);
      } else {
        throw ServerException('Failed to get product', response.statusCode);
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<List<ProductModel>> getAvailableProducts() async {
    try {
      final response = await dio.get(ApiConstants.availableProducts);

      if (response.statusCode == 200) {
        return ApiResponseUtils.list(response)
            .whereType<Map<String, dynamic>>()
            .map(ProductModel.fromJson)
            .toList();
      } else {
        throw ServerException(
          'Failed to get available products',
          response.statusCode,
        );
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<List<ProductModel>> getLowStockProducts() async {
    try {
      final response = await dio.get(ApiConstants.lowStockProducts);

      if (response.statusCode == 200) {
        return ApiResponseUtils.list(response)
            .whereType<Map<String, dynamic>>()
            .map(ProductModel.fromJson)
            .toList();
      } else {
        throw ServerException(
          'Failed to get low stock products',
          response.statusCode,
        );
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<List<ProductModel>> getProductsByCategory(String categoryId) async {
    try {
      final response =
          await dio.get(ApiConstants.productsByCategory(categoryId));

      if (response.statusCode == 200) {
        return ApiResponseUtils.list(response)
            .whereType<Map<String, dynamic>>()
            .map(ProductModel.fromJson)
            .toList();
      } else {
        throw ServerException(
          'Failed to get products by category',
          response.statusCode,
        );
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<ProductModel> getProductBySku(String sku) async {
    try {
      final response = await dio.get(ApiConstants.productBySku(sku));

      if (response.statusCode == 200) {
        return ProductModel.fromJson(response.data);
      } else {
        throw ServerException('Failed to get product by SKU', response.statusCode);
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<ProductModel> createProduct(Map<String, dynamic> data) async {
    try {
      final response = await dio.post(
        ApiConstants.products,
        data: data,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return ProductModel.fromJson(response.data);
      } else {
        throw ServerException('Failed to create product', response.statusCode);
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<ProductModel> updateProduct(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await dio.patch(
        ApiConstants.productById(id),
        data: data,
      );

      if (response.statusCode == 200) {
        return ProductModel.fromJson(response.data);
      } else {
        throw ServerException('Failed to update product', response.statusCode);
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<ProductModel> updateStock({
    required String id,
    required int quantity,
    required String operation,
  }) async {
    try {
      final response = await dio.patch(
        ApiConstants.updateProductStock(id),
        data: {
          'quantity': quantity,
          'operation': operation,
        },
      );

      if (response.statusCode == 200) {
        return ProductModel.fromJson(response.data);
      } else {
        throw ServerException('Failed to update stock', response.statusCode);
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<void> deleteProduct(String id) async {
    try {
      final response = await dio.delete(ApiConstants.productById(id));

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ServerException('Failed to delete product', response.statusCode);
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<ProductVariantModel> createVariant(Map<String, dynamic> data) async {
    try {
      final response = await dio.post(
        ApiConstants.variants,
        data: data,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return ProductVariantModel.fromJson(response.data);
      } else {
        throw ServerException('Failed to create variant', response.statusCode);
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<ProductVariantModel> updateVariant(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await dio.patch(
        ApiConstants.variantById(id),
        data: data,
      );

      if (response.statusCode == 200) {
        return ProductVariantModel.fromJson(response.data);
      } else {
        throw ServerException('Failed to update variant', response.statusCode);
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<void> deleteVariant(String id) async {
    try {
      final response = await dio.delete(ApiConstants.variantById(id));

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ServerException('Failed to delete variant', response.statusCode);
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  // Modifier methods implementation
  @override
  Future<List<ModifierModel>> getModifiers({
    String? productId,
    String? categoryId,
    bool? isAvailable,
  }) async {
    try {
      String endpoint;
      if (productId != null) {
        endpoint = ApiConstants.modifiersByProduct(productId);
      } else if (categoryId != null) {
        endpoint = ApiConstants.modifiersByCategory(categoryId);
      } else if (isAvailable == true) {
        endpoint = ApiConstants.availableModifiers;
      } else {
        // Listado completo: endpoint dedicado del backend (`/all`).
        endpoint = ApiConstants.modifiersAll;
      }

      final response = await dio.get(endpoint);

      if (response.statusCode == 200) {
        final List<dynamic> data;
        if (response.data is List) {
          data = response.data as List<dynamic>;
        } else if (response.data is Map && response.data['data'] != null) {
          data = response.data['data'] as List<dynamic>;
        } else {
          throw ServerException('Unexpected response format', response.statusCode);
        }
        return data.map((json) => ModifierModel.fromJson(json)).toList();
      } else {
        throw ServerException('Failed to get modifiers', response.statusCode);
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<ModifierModel> getModifierById(String id) async {
    try {
      final response = await dio.get(ApiConstants.modifierById(id));

      if (response.statusCode == 200) {
        return ModifierModel.fromJson(response.data);
      } else {
        throw ServerException('Failed to get modifier', response.statusCode);
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<ModifierModel> createModifier(Map<String, dynamic> data) async {
    try {
      final response = await dio.post(
        ApiConstants.modifiers,
        data: data,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return ModifierModel.fromJson(response.data);
      } else {
        throw ServerException('Failed to create modifier', response.statusCode);
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<ModifierModel> updateModifier(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await dio.patch(
        ApiConstants.modifierById(id),
        data: data,
      );

      if (response.statusCode == 200) {
        return ModifierModel.fromJson(response.data);
      } else {
        throw ServerException('Failed to update modifier', response.statusCode);
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<void> deleteModifier(String id) async {
    try {
      final response = await dio.delete(ApiConstants.modifierById(id));

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ServerException('Failed to delete modifier', response.statusCode);
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  // Modifier Group methods implementation
  @override
  Future<List<ModifierGroupModel>> getModifierGroups({
    String? productId,
    bool? isActive,
  }) async {
    try {
      String endpoint;
      if (productId != null) {
        endpoint = ApiConstants.modifierGroupsByProduct(productId);
      } else if (isActive == true) {
        endpoint = ApiConstants.activeModifierGroups;
      } else {
        endpoint = ApiConstants.modifierGroups;
      }

      final response = await dio.get(endpoint);

      if (response.statusCode == 200) {
        final List<dynamic> data;
        if (response.data is List) {
          data = response.data as List<dynamic>;
        } else if (response.data is Map && response.data['data'] != null) {
          data = response.data['data'] as List<dynamic>;
        } else {
          throw ServerException('Unexpected response format', response.statusCode);
        }
        return data.map((json) => ModifierGroupModel.fromJson(json)).toList();
      } else {
        throw ServerException('Failed to get modifier groups', response.statusCode);
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<ModifierGroupModel> createModifierGroup(
      Map<String, dynamic> data) async {
    try {
      final response = await dio.post(
        ApiConstants.modifierGroups,
        data: data,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return ModifierGroupModel.fromJson(response.data);
      } else {
        throw ServerException(
            'Failed to create modifier group', response.statusCode);
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<ModifierGroupModel> updateModifierGroup(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await dio.patch(
        ApiConstants.modifierGroupById(id),
        data: data,
      );

      if (response.statusCode == 200) {
        return ModifierGroupModel.fromJson(response.data);
      } else {
        throw ServerException(
            'Failed to update modifier group', response.statusCode);
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<void> deleteModifierGroup(String id) async {
    try {
      final response = await dio.delete(ApiConstants.modifierGroupById(id));

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ServerException(
            'Failed to delete modifier group', response.statusCode);
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<ModifierGroupModel> addModifiersToGroup(
    String groupId,
    List<String> modifierIds,
  ) async {
    try {
      final response = await dio.post(
        ApiConstants.addModifiersToGroup(groupId),
        data: {'modifier_ids': modifierIds},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ModifierGroupModel.fromJson(response.data);
      } else {
        throw ServerException(
          'Failed to add modifiers to group',
          response.statusCode,
        );
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<void> removeModifierFromGroup(
    String groupId,
    String modifierId,
  ) async {
    try {
      final response = await dio.delete(
        ApiConstants.removeModifierFromGroup(groupId, modifierId),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ServerException(
          'Failed to remove modifier from group',
          response.statusCode,
        );
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  void _handleDioException(DioException e) {
    if (e.response?.statusCode == 401) {
      throw UnauthorizedException('Unauthorized');
    } else if (e.response?.statusCode == 404) {
      throw NotFoundException('Product not found');
    } else if (e.response?.statusCode == 400) {
      throw ValidationException(
        e.response?.data['message'] ?? 'Validation error',
      );
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw NetworkException('Connection timeout');
    } else if (e.type == DioExceptionType.unknown) {
      throw NetworkException('No internet connection');
    } else {
      throw ServerException(
        e.response?.data['message'] ?? 'Server error',
        e.response?.statusCode,
      );
    }
  }
}
