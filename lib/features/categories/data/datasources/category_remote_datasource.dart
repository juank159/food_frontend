// lib/frontend/lib/features/categories/data/datasources/category_remote_datasource.dart

import 'package:dio/dio.dart';
import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../models/category_model.dart';

/// Category Remote Data Source
/// Fuente de datos remota para categorías
abstract class CategoryRemoteDataSource {
  /// Obtiene todas las categorías
  Future<List<CategoryModel>> getCategories({
    bool? isActive,
    String? search,
    int? page,
    int? limit,
  });

  /// Obtiene el árbol de categorías
  Future<List<CategoryModel>> getCategoryTree({bool? isActive});

  /// Obtiene solo las categorías activas
  Future<List<CategoryModel>> getActiveCategories();

  /// Obtiene solo las categorías raíz
  Future<List<CategoryModel>> getRootCategories({bool? isActive});

  /// Obtiene una categoría por ID
  Future<CategoryModel> getCategoryById(String id);

  /// Obtiene las subcategorías de una categoría padre
  Future<List<CategoryModel>> getSubcategories(String parentId);

  /// Crea una nueva categoría
  Future<CategoryModel> createCategory({
    required String name,
    required String description,
    String? imageUrl,
    String? color,
    String? icon,
    bool isActive = true,
    int displayOrder = 0,
    String? parentId,
    bool printsKitchen = true,
  });

  /// Actualiza una categoría
  Future<CategoryModel> updateCategory({
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
  });

  /// Elimina una categoría
  Future<void> deleteCategory(String id);
}

/// Implementación del data source remoto de categorías
class CategoryRemoteDataSourceImpl implements CategoryRemoteDataSource {
  final Dio dio;

  CategoryRemoteDataSourceImpl({required this.dio});

  @override
  Future<List<CategoryModel>> getCategories({
    bool? isActive,
    String? search,
    int? page,
    int? limit,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (isActive != null) queryParams['is_active'] = isActive;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (page != null) queryParams['page'] = page;
      if (limit != null) queryParams['limit'] = limit;

      final response = await dio.get(
        ApiConstants.categories,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        // Manejo robusto de la respuesta
        final responseData = response.data;

        if (responseData is List) {
          // Si la respuesta es directamente una lista
          return responseData.map((json) => CategoryModel.fromJson(json)).toList();
        } else if (responseData is Map<String, dynamic>) {
          // Si la respuesta es un objeto con 'data'
          final List<dynamic> data = responseData['data'] ?? [];
          return data.map((json) => CategoryModel.fromJson(json)).toList();
        } else {
          throw ServerException('Invalid response format');
        }
      } else {
        throw ServerException('Failed to load categories');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<List<CategoryModel>> getCategoryTree({bool? isActive}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (isActive != null) queryParams['is_active'] = isActive;

      final response = await dio.get(
        ApiConstants.categoryTree,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData is List) {
          return responseData.map((json) => CategoryModel.fromJson(json)).toList();
        } else if (responseData is Map<String, dynamic>) {
          final List<dynamic> data = responseData['data'] ?? [];
          return data.map((json) => CategoryModel.fromJson(json)).toList();
        } else {
          throw ServerException('Invalid response format');
        }
      } else {
        throw ServerException('Failed to load category tree');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<List<CategoryModel>> getActiveCategories() async {
    try {
      final response = await dio.get(ApiConstants.activeCategories);

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData is List) {
          return responseData.map((json) => CategoryModel.fromJson(json)).toList();
        } else if (responseData is Map<String, dynamic>) {
          final List<dynamic> data = responseData['data'] ?? [];
          return data.map((json) => CategoryModel.fromJson(json)).toList();
        } else {
          throw ServerException('Invalid response format');
        }
      } else {
        throw ServerException('Failed to load active categories');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<List<CategoryModel>> getRootCategories({bool? isActive}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (isActive != null) queryParams['is_active'] = isActive;

      final response = await dio.get(
        ApiConstants.rootCategories,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData is List) {
          return responseData.map((json) => CategoryModel.fromJson(json)).toList();
        } else if (responseData is Map<String, dynamic>) {
          final List<dynamic> data = responseData['data'] ?? [];
          return data.map((json) => CategoryModel.fromJson(json)).toList();
        } else {
          throw ServerException('Invalid response format');
        }
      } else {
        throw ServerException('Failed to load root categories');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<CategoryModel> getCategoryById(String id) async {
    try {
      final response = await dio.get(ApiConstants.categoryById(id));

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData is Map<String, dynamic>) {
          // Si la respuesta tiene un campo 'data', usarlo; sino usar toda la respuesta
          final data = responseData['data'] ?? responseData;
          return CategoryModel.fromJson(data);
        } else {
          throw ServerException('Invalid response format');
        }
      } else {
        throw ServerException('Failed to load category');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<List<CategoryModel>> getSubcategories(String parentId) async {
    try {
      final response = await dio.get(ApiConstants.subcategories(parentId));

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData is List) {
          return responseData.map((json) => CategoryModel.fromJson(json)).toList();
        } else if (responseData is Map<String, dynamic>) {
          final List<dynamic> data = responseData['data'] ?? [];
          return data.map((json) => CategoryModel.fromJson(json)).toList();
        } else {
          throw ServerException('Invalid response format');
        }
      } else {
        throw ServerException('Failed to load subcategories');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<CategoryModel> createCategory({
    required String name,
    required String description,
    String? imageUrl,
    String? color,
    String? icon,
    bool isActive = true,
    int displayOrder = 0,
    String? parentId,
    bool printsKitchen = true,
  }) async {
    try {
      // NOTA: el backend usa `whitelist + forbidNonWhitelisted` en el
      // ValidationPipe global. La entidad/DTO actual NO tiene `color`
      // ni `icon`, así que NO los enviamos para evitar 400. Los inputs
      // del form quedan como preview local hasta que el backend los
      // soporte.
      final requestBody = <String, dynamic>{
        'name': name,
        'description': description,
        'is_active': isActive,
        'sort_order': displayOrder,
        'prints_kitchen': printsKitchen,
      };

      if (imageUrl != null) requestBody['image_url'] = imageUrl;
      if (parentId != null) requestBody['parent_category_id'] = parentId;

      final response = await dio.post(
        ApiConstants.categories,
        data: requestBody,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = response.data;

        if (responseData is Map<String, dynamic>) {
          final data = responseData['data'] ?? responseData;
          return CategoryModel.fromJson(data);
        } else {
          throw ServerException('Invalid response format');
        }
      } else {
        throw ServerException('Failed to create category');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<CategoryModel> updateCategory({
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
  }) async {
    try {
      final requestBody = <String, dynamic>{};

      if (name != null) requestBody['name'] = name;
      if (description != null) requestBody['description'] = description;
      if (imageUrl != null) requestBody['image_url'] = imageUrl;
      if (isActive != null) requestBody['is_active'] = isActive;
      if (displayOrder != null) requestBody['sort_order'] = displayOrder;
      if (parentId != null) requestBody['parent_category_id'] = parentId;
      if (printsKitchen != null) {
        requestBody['prints_kitchen'] = printsKitchen;
      }

      final response = await dio.patch(
        ApiConstants.categoryById(id),
        data: requestBody,
      );

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData is Map<String, dynamic>) {
          final data = responseData['data'] ?? responseData;
          return CategoryModel.fromJson(data);
        } else {
          throw ServerException('Invalid response format');
        }
      } else {
        throw ServerException('Failed to update category');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    try {
      final response = await dio.delete(ApiConstants.categoryById(id));

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ServerException('Failed to delete category');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  /// Maneja excepciones de Dio y las convierte a excepciones personalizadas
  void _handleDioException(DioException e) {
    if (e.response?.statusCode == 401) {
      throw UnauthorizedException('Unauthorized');
    } else if (e.response?.statusCode == 404) {
      throw NotFoundException('Category not found');
    } else if (e.response?.statusCode == 400) {
      final messageData = e.response?.data['message'];
      String message;
      if (messageData is List) {
        // Si es un array, unir los mensajes
        message = messageData.join(', ');
      } else if (messageData is String) {
        message = messageData;
      } else {
        message = 'Bad request';
      }
      throw ValidationException(message);
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw NetworkException('Connection timeout');
    } else if (e.type == DioExceptionType.unknown) {
      throw NetworkException('Network error: ${e.message}');
    } else {
      final messageData = e.response?.data['message'];
      String message;
      if (messageData is List) {
        message = messageData.join(', ');
      } else if (messageData is String) {
        message = messageData;
      } else {
        message = 'Server error occurred';
      }
      throw ServerException(message);
    }
  }
}
