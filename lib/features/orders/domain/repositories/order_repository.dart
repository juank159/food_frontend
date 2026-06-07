import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/error/failures.dart';
import '../entities/order.dart' as order_entity;

/// Order Repository
/// Contrato de repositorio para órdenes
abstract class OrderRepository {
  /// Obtiene todas las órdenes con filtros opcionales
  Future<Either<Failure, List<order_entity.Order>>> getOrders({
    OrderStatus? status,
    OrderType? orderType,
    String? tableId,
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    int? page,
    int? limit,
  });

  /// Obtiene una orden por ID
  Future<Either<Failure, order_entity.Order>> getOrderById(String id);

  /// Obtiene órdenes por número de orden
  Future<Either<Failure, order_entity.Order>> getOrderByNumber(String orderNumber);

  /// Obtiene órdenes activas (en proceso)
  Future<Either<Failure, List<order_entity.Order>>> getActiveOrders();

  /// Obtiene órdenes por mesa
  Future<Either<Failure, List<order_entity.Order>>> getOrdersByTable(String tableId);

  /// Obtiene órdenes por cliente
  Future<Either<Failure, List<order_entity.Order>>> getOrdersByCustomer(String customerId);

  /// Obtiene órdenes pendientes de pago
  Future<Either<Failure, List<order_entity.Order>>> getPendingPaymentOrders();

  /// Crea una nueva orden
  Future<Either<Failure, order_entity.Order>> createOrder({
    required OrderType orderType,
    OrderSource orderSource = OrderSource.pos,
    String? tableId,
    String? tableElementId, // Floor Plan Table Element ID
    String? tabSessionId,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    Map<String, dynamic>? deliveryAddress,
    String? assignedTo,
    required List<Map<String, dynamic>> items,
    String? specialInstructions,
    double discountAmount = 0,
    double? discountPercentage,
    double deliveryFee = 0,
    double tipAmount = 0,
    double? taxAmount,
    PaymentMethod? paymentMethod,
    int? estimatedTime,
    Map<String, dynamic>? metadata,
  });

  /// Actualiza el estado de una orden
  Future<Either<Failure, order_entity.Order>> updateOrderStatus({
    required String id,
    required OrderStatus status,
  });

  /// Actualiza información de una orden
  Future<Either<Failure, order_entity.Order>> updateOrder({
    required String id,
    OrderStatus? status,
    String? tableId,
    String? customerId,
    String? customerName,
    String? assignedTo,
    String? specialInstructions,
    Map<String, dynamic>? deliveryAddress,
    int? estimatedTime,
  });

  /// Asigna una orden a un usuario
  Future<Either<Failure, order_entity.Order>> assignOrder({
    required String id,
    required String userId,
  });

  /// Actualiza el método de pago
  Future<Either<Failure, order_entity.Order>> updatePaymentMethod({
    required String id,
    required PaymentMethod paymentMethod,
  });

  /// Marca una orden como pagada
  Future<Either<Failure, order_entity.Order>> markAsPaid({
    required String id,
    required PaymentMethod paymentMethod,
  });

  /// Cancela una orden
  Future<Either<Failure, order_entity.Order>> cancelOrder({
    required String id,
    String? reason,
  });

  /// Elimina una orden
  Future<Either<Failure, void>> deleteOrder(String id);
}
