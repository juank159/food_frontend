import 'package:dio/dio.dart';
import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../models/order_model.dart';

/// Order Remote Data Source
/// Fuente de datos remota para órdenes
abstract class OrderRemoteDataSource {
  Future<List<OrderModel>> getOrders({
    OrderStatus? status,
    OrderType? orderType,
    String? tableId,
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    int? page,
    int? limit,
  });

  Future<OrderModel> getOrderById(String id);
  Future<OrderModel> getOrderByNumber(String orderNumber);
  Future<List<OrderModel>> getActiveOrders();
  Future<List<OrderModel>> getOrdersByTable(String tableId);
  Future<List<OrderModel>> getOrdersByCustomer(String customerId);
  Future<List<OrderModel>> getPendingPaymentOrders();

  Future<OrderModel> createOrder(Map<String, dynamic> orderData);
  Future<OrderModel> updateOrderStatus(String id, OrderStatus status);

  /// Actualiza el estado de UN item. La orden se auto-avanza cuando
  /// todos los items con `requires_preparation` llegan a `ready` /
  /// `delivered`.
  Future<OrderModel> updateOrderItemStatus(
    String orderId,
    String itemId,
    OrderStatus status,
  );
  Future<OrderModel> updateOrder(String id, Map<String, dynamic> orderData);
  Future<OrderModel> assignOrder(String id, String userId);
  Future<OrderModel> markAsPaid(String id, PaymentMethod paymentMethod);
  Future<OrderModel> cancelOrder(String id, String? reason);
  Future<void> deleteOrder(String id);

  /// Cola self-order pendientes de aprobación del mesero.
  /// Devuelve count + items en una sola respuesta (el backend agrupa).
  Future<PendingReviewBatch> getPendingReviewOrders();

  /// Aprueba una self-order (PENDING_REVIEW → PENDING o CONFIRMED).
  /// [toConfirmed] = true salta directo a CONFIRMED.
  Future<OrderModel> approveSelfOrder(String id, {bool toConfirmed = false});

  /// Rechaza una self-order (PENDING_REVIEW → CANCELLED) con razón.
  Future<OrderModel> rejectSelfOrder(String id, String reason);
}

/// Tuple count + items para la cola de pending-review.
/// El backend lo devuelve junto para evitar doble request (badge + lista).
class PendingReviewBatch {
  final int count;
  final List<OrderModel> items;

  const PendingReviewBatch({required this.count, required this.items});
}

/// Implementación del data source remoto de órdenes.
///
/// Usa `ApiResponseUtils` para parsear respuestas porque el backend
/// devuelve formatos heterogéneos según el endpoint (lista directa,
/// envuelto en `data`, envuelto con `meta`, etc.). Hardcodear
/// `response.data['data']` crasheaba con `type 'String' is not a
/// subtype of type 'int' of 'index'` cuando el endpoint devolvía
/// una `List` directa.
class OrderRemoteDataSourceImpl implements OrderRemoteDataSource {
  final Dio dio;

  OrderRemoteDataSourceImpl({required this.dio});

  @override
  Future<List<OrderModel>> getOrders({
    OrderStatus? status,
    OrderType? orderType,
    String? tableId,
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    int? page,
    int? limit,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null) queryParams['status'] = status.value;
      if (orderType != null) queryParams['order_type'] = orderType.value;
      if (tableId != null) queryParams['table_id'] = tableId;
      if (customerId != null) queryParams['customer_id'] = customerId;
      // El backend espera `date_from` / `date_to` (ver
      // orders.controller.ts @Query). Antes mandábamos `start_date` /
      // `end_date`, que el backend ignoraba en silencio → el filtro de
      // fecha nunca tomaba efecto (acá y en reportes).
      if (startDate != null) {
        queryParams['date_from'] = startDate.toIso8601String();
      }
      if (endDate != null) queryParams['date_to'] = endDate.toIso8601String();
      if (page != null) queryParams['page'] = page;
      if (limit != null) queryParams['limit'] = limit;

      final response = await dio.get(
        ApiConstants.orders,
        queryParameters: queryParams,
      );

      return ApiResponseUtils.list(response)
          .whereType<Map<String, dynamic>>()
          .map(OrderModel.fromJson)
          .toList();
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<OrderModel> getOrderById(String id) async {
    try {
      final response = await dio.get(ApiConstants.orderById(id));
      return OrderModel.fromJson(ApiResponseUtils.object(response));
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<OrderModel> getOrderByNumber(String orderNumber) async {
    try {
      final response =
          await dio.get('${ApiConstants.orders}/number/$orderNumber');
      return OrderModel.fromJson(ApiResponseUtils.object(response));
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<List<OrderModel>> getActiveOrders() async {
    try {
      final response = await dio.get('${ApiConstants.orders}/active');
      return ApiResponseUtils.list(response)
          .whereType<Map<String, dynamic>>()
          .map(OrderModel.fromJson)
          .toList();
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<List<OrderModel>> getOrdersByTable(String tableId) async {
    try {
      final response = await dio.get(
        ApiConstants.orders,
        queryParameters: {'table_id': tableId},
      );
      return ApiResponseUtils.list(response)
          .whereType<Map<String, dynamic>>()
          .map(OrderModel.fromJson)
          .toList();
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<List<OrderModel>> getOrdersByCustomer(String customerId) async {
    try {
      final response =
          await dio.get(ApiConstants.ordersByCustomer(customerId));
      return ApiResponseUtils.list(response)
          .whereType<Map<String, dynamic>>()
          .map(OrderModel.fromJson)
          .toList();
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<List<OrderModel>> getPendingPaymentOrders() async {
    try {
      final response = await dio.get(
        ApiConstants.orders,
        queryParameters: {'payment_status': 'pending'},
      );
      return ApiResponseUtils.list(response)
          .whereType<Map<String, dynamic>>()
          .map(OrderModel.fromJson)
          .toList();
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<OrderModel> createOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await dio.post(ApiConstants.orders, data: orderData);
      return OrderModel.fromJson(ApiResponseUtils.object(response));
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<OrderModel> updateOrderStatus(String id, OrderStatus status) async {
    try {
      final response = await dio.patch(
        ApiConstants.orderStatus(id),
        data: {'status': status.value},
      );
      return OrderModel.fromJson(ApiResponseUtils.object(response));
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<OrderModel> updateOrderItemStatus(
    String orderId,
    String itemId,
    OrderStatus status,
  ) async {
    try {
      final response = await dio.patch(
        '/orders/$orderId/items/$itemId/status',
        data: {'status': status.value},
      );
      return OrderModel.fromJson(ApiResponseUtils.object(response));
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<OrderModel> updateOrder(
    String id,
    Map<String, dynamic> orderData,
  ) async {
    try {
      final response =
          await dio.patch(ApiConstants.orderById(id), data: orderData);
      return OrderModel.fromJson(ApiResponseUtils.object(response));
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<OrderModel> assignOrder(String id, String userId) async {
    try {
      final response = await dio.patch(
        ApiConstants.orderById(id),
        data: {'assigned_to': userId},
      );
      return OrderModel.fromJson(ApiResponseUtils.object(response));
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<OrderModel> markAsPaid(String id, PaymentMethod paymentMethod) async {
    try {
      final response = await dio.patch(
        ApiConstants.orderById(id),
        data: {
          'payment_status': 'completed',
          'payment_method': paymentMethod.value,
        },
      );
      return OrderModel.fromJson(ApiResponseUtils.object(response));
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<OrderModel> cancelOrder(String id, String? reason) async {
    try {
      final requestBody = <String, dynamic>{'status': 'cancelled'};
      if (reason != null) requestBody['cancellation_reason'] = reason;

      final response =
          await dio.patch(ApiConstants.orderById(id), data: requestBody);
      return OrderModel.fromJson(ApiResponseUtils.object(response));
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<PendingReviewBatch> getPendingReviewOrders() async {
    try {
      final response = await dio.get(ApiConstants.pendingReviewOrders);
      final payload = ApiResponseUtils.object(response);
      final itemsRaw = (payload['items'] as List?) ?? const [];
      final items = itemsRaw
          .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
          .toList();
      // Si el backend no envía count (debería), lo derivamos del array.
      final count = payload['count'] is int
          ? payload['count'] as int
          : items.length;
      return PendingReviewBatch(count: count, items: items);
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<OrderModel> approveSelfOrder(
    String id, {
    bool toConfirmed = false,
  }) async {
    try {
      final response = await dio.post(
        ApiConstants.approveOrder(id),
        queryParameters: toConfirmed ? {'to': 'confirmed'} : null,
      );
      return OrderModel.fromJson(ApiResponseUtils.object(response));
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<OrderModel> rejectSelfOrder(String id, String reason) async {
    try {
      final response = await dio.post(
        ApiConstants.rejectOrder(id),
        data: {'reason': reason},
      );
      return OrderModel.fromJson(ApiResponseUtils.object(response));
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<void> deleteOrder(String id) async {
    try {
      final response = await dio.delete(ApiConstants.orderById(id));
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ServerException('Failed to delete order');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  void _handleDioException(DioException e) {
    final body = ApiResponseUtils.errorMessage(e);
    if (e.response?.statusCode == 401) {
      throw UnauthorizedException('Unauthorized');
    } else if (e.response?.statusCode == 404) {
      throw NotFoundException(body ?? 'Order not found');
    } else if (e.response?.statusCode == 400) {
      throw ValidationException(body ?? 'Bad request');
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw NetworkException('Connection timeout');
    } else if (e.type == DioExceptionType.unknown) {
      throw NetworkException('Network error: ${e.message}');
    } else {
      throw ServerException(body ?? 'Server error occurred');
    }
  }
}
