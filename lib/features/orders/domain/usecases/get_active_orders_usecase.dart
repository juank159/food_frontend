import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/order.dart' as order_entity;
import '../repositories/order_repository.dart';

/// Get Active Orders Use Case
/// Obtiene todas las órdenes activas (en proceso)
class GetActiveOrdersUseCase {
  final OrderRepository repository;

  GetActiveOrdersUseCase(this.repository);

  Future<Either<Failure, List<order_entity.Order>>> call() async {
    return await repository.getActiveOrders();
  }
}
