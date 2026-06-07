import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/error/failures.dart';
import '../entities/order.dart' as order_entity;
import '../repositories/order_repository.dart';

/// Update Order Status Use Case
/// Actualiza el estado de una orden
class UpdateOrderStatusUseCase {
  final OrderRepository repository;

  UpdateOrderStatusUseCase(this.repository);

  Future<Either<Failure, order_entity.Order>> call({
    required String id,
    required OrderStatus status,
  }) async {
    return await repository.updateOrderStatus(
      id: id,
      status: status,
    );
  }
}
