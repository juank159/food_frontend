import 'package:dio/dio.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/inventory_movement.dart';
import '../models/inventory_item_model.dart';

/// Inventory Remote Data Source
///
/// El backend no expone endpoints "inventory" propios — usamos los de
/// products:
///
///   - `GET /products` para listar.
///   - `PATCH /products/:id` para ajustar stock (campos `current_stock`,
///     `min_stock_alert`, opcionalmente `track_inventory`).
///   - `GET /products/:id/inventory-history` para el histórico de
///     movimientos (ajustes manuales, consumo por orden, devoluciones).
abstract class InventoryRemoteDataSource {
  Future<List<InventoryItemModel>> getInventory();

  Future<InventoryItemModel> adjustStock({
    required String productId,
    required int currentStock,
    int? minStockAlert,
    String? reason,
  });

  Future<List<InventoryMovement>> getInventoryHistory({
    required String productId,
    int limit = 50,
  });
}

class InventoryRemoteDataSourceImpl implements InventoryRemoteDataSource {
  final Dio dio;

  InventoryRemoteDataSourceImpl({required this.dio});

  @override
  Future<List<InventoryItemModel>> getInventory() async {
    try {
      final response = await dio.get(ApiConstants.products);

      if (response.statusCode == 200) {
        // El endpoint puede devolver lista plana o `{data: [...]}`,
        // según se observa en `ProductRemoteDataSource`.
        final List<dynamic> data;
        final raw = response.data;
        if (raw is List) {
          data = raw;
        } else if (raw is Map && raw['data'] is List) {
          data = raw['data'] as List<dynamic>;
        } else {
          throw ServerException('Unexpected products response format');
        }
        return data
            .whereType<Map<String, dynamic>>()
            .map(InventoryItemModel.fromJson)
            .toList();
      } else {
        throw ServerException('Failed to load inventory');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<InventoryItemModel> adjustStock({
    required String productId,
    required int currentStock,
    int? minStockAlert,
    String? reason,
  }) async {
    try {
      // Garantizamos `track_inventory: true` cuando se envía un stock —
      // si el producto venía sin tracking, necesitamos prenderlo para
      // que los flags (low/out) tengan sentido.
      final payload = <String, dynamic>{
        'current_stock': currentStock,
        'track_inventory': true,
      };
      if (minStockAlert != null) {
        payload['min_stock_alert'] = minStockAlert;
      }
      if (reason != null && reason.isNotEmpty) {
        // El backend no persiste este campo hoy; lo enviamos para que
        // quede en logs y para no perder el motivo si se agrega audit.
        payload['adjustment_reason'] = reason;
      }

      final response = await dio.patch(
        ApiConstants.productById(productId),
        data: payload,
      );

      if (response.statusCode == 200) {
        // PATCH /products/:id devuelve el producto plano (sin envoltorio).
        final raw = response.data;
        final Map<String, dynamic> data;
        if (raw is Map<String, dynamic>) {
          data = raw['data'] is Map
              ? (raw['data'] as Map).cast<String, dynamic>()
              : raw;
        } else {
          throw ServerException('Unexpected adjust response format');
        }
        return InventoryItemModel.fromJson(data);
      } else {
        throw ServerException('Failed to adjust stock');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<List<InventoryMovement>> getInventoryHistory({
    required String productId,
    int limit = 50,
  }) async {
    try {
      final response = await dio.get(
        '${ApiConstants.products}/$productId/inventory-history',
        queryParameters: {'limit': limit},
      );

      if (response.statusCode == 200) {
        final raw = response.data;
        final List<dynamic> data;
        if (raw is List) {
          data = raw;
        } else if (raw is Map && raw['data'] is List) {
          data = raw['data'] as List<dynamic>;
        } else {
          throw ServerException('Unexpected history response format');
        }
        return data
            .whereType<Map<String, dynamic>>()
            .map(_movementFromJson)
            .toList();
      } else {
        throw ServerException('Failed to load inventory history');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  /// Mapea un movimiento del JSON del backend a la entidad de dominio.
  /// El backend devuelve `user` como objeto relación; nosotros aplanamos
  /// a `userName` para no arrastrar la entidad User completa.
  InventoryMovement _movementFromJson(Map<String, dynamic> json) {
    final user = json['user'];
    String? userName;
    if (user is Map<String, dynamic>) {
      final first = user['first_name'] as String? ?? '';
      final last = user['last_name'] as String? ?? '';
      final full = ('$first $last').trim();
      userName = full.isEmpty ? (user['email'] as String?) : full;
    }
    return InventoryMovement(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      delta: (json['delta'] as num).toInt(),
      stockAfter: (json['stock_after'] as num).toInt(),
      reason: InventoryMovementReason.fromCode(json['reason'] as String),
      userId: json['user_id'] as String?,
      userName: userName,
      orderId: json['order_id'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  void _handleDioException(DioException e) {
    if (e.response?.statusCode == 401) {
      throw UnauthorizedException('Unauthorized');
    } else if (e.response?.statusCode == 404) {
      throw NotFoundException('Product not found');
    } else if (e.response?.statusCode == 400) {
      final message = e.response?.data is Map
          ? (ApiResponseUtils.errorMessage(e) ?? 'Bad request')
          : 'Bad request';
      throw ValidationException(message);
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw NetworkException('Connection timeout');
    } else if (e.type == DioExceptionType.unknown) {
      throw NetworkException('Network error: ${e.message}');
    } else {
      final fallback = e.response?.data is Map
          ? (ApiResponseUtils.errorMessage(e) ??
              'Server error occurred')
          : 'Server error occurred';
      throw ServerException(fallback);
    }
  }
}
