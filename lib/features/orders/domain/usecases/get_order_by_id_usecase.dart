import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/order.dart' as order_entity;
import '../repositories/order_repository.dart';

/// Get Order By ID Use Case
/// Obtiene una orden específica por su ID
class GetOrderByIdUseCase {
  final OrderRepository repository;

  GetOrderByIdUseCase(this.repository);

  Future<Either<Failure, order_entity.Order>> call(String id) async {
    return await repository.getOrderById(id);
  }
}
