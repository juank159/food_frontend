import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/order.dart' as order_entity;
import '../repositories/order_repository.dart';

/// Update Order Use Case.
///
/// Edita metadata de una orden existente — instrucciones especiales,
/// mesa asignada, cliente, dirección de domicilio, tiempo estimado.
///
/// Limitación actual: NO permite modificar items (cantidades, productos,
/// modifiers). Para eso hay que cancelar+recrear o agregar el endpoint
/// `replaceItems` en el backend (TODO documentado en backlog).
class UpdateOrderUseCase {
  final OrderRepository repository;

  UpdateOrderUseCase(this.repository);

  Future<Either<Failure, order_entity.Order>> call({
    required String id,
    String? tableId,
    String? customerId,
    String? customerName,
    String? assignedTo,
    String? specialInstructions,
    Map<String, dynamic>? deliveryAddress,
    int? estimatedTime,
  }) async {
    return repository.updateOrder(
      id: id,
      tableId: tableId,
      customerId: customerId,
      customerName: customerName,
      assignedTo: assignedTo,
      specialInstructions: specialInstructions,
      deliveryAddress: deliveryAddress,
      estimatedTime: estimatedTime,
    );
  }
}
