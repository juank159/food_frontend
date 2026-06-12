import 'package:dartz/dartz.dart';

import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/error/failures.dart';
import '../entities/order.dart' as order_entity;
import '../repositories/order_repository.dart';

/// Actualiza el estado de UN item de una orden. El backend mantiene los
/// timestamps `prepared_at` / `delivered_at` y, cuando todos los items
/// con preparación quedan en `ready` o `delivered`, avanza la orden
/// completa automáticamente. La UI no tiene que tocar el status de la
/// orden — solo marca items.
class UpdateOrderItemStatusUseCase {
  final OrderRepository repository;

  UpdateOrderItemStatusUseCase(this.repository);

  Future<Either<Failure, order_entity.Order>> call({
    required String orderId,
    required String itemId,
    required OrderStatus status,
  }) {
    return repository.updateOrderItemStatus(
      orderId: orderId,
      itemId: itemId,
      status: status,
    );
  }
}
