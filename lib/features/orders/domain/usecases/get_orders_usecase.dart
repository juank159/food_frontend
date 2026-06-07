import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/error/failures.dart';
import '../entities/order.dart' as order_entity;
import '../repositories/order_repository.dart';

/// Get Orders Use Case
/// Obtiene todas las órdenes con filtros opcionales
class GetOrdersUseCase {
  final OrderRepository repository;

  GetOrdersUseCase(this.repository);

  Future<Either<Failure, List<order_entity.Order>>> call({
    OrderStatus? status,
    OrderType? orderType,
    String? tableId,
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    int? page,
    int? limit,
  }) async {
    return await repository.getOrders(
      status: status,
      orderType: orderType,
      tableId: tableId,
      customerId: customerId,
      startDate: startDate,
      endDate: endDate,
      page: page,
      limit: limit,
    );
  }
}
