import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/reservation_repository.dart';

/// Convierte el pre-pedido de invitados de una reserva en una orden real
/// (dine-in) — paso manual, deliberado: el anfitrión decide cuándo
/// "cerrar" el pre-pedido y pasarlo a cocina/cobro. Devuelve el `id` de
/// la orden creada.
class CreateOrderFromPreorderUseCase {
  final ReservationRepository repository;

  CreateOrderFromPreorderUseCase(this.repository);

  Future<Either<Failure, String>> call(String id) {
    return repository.createOrderFromPreorder(id);
  }
}
