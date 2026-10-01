import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/reservation_repository.dart';

/// Abre/cierra la recepción de nuevos items de invitados en el
/// pre-pedido colaborativo de una reserva.
class SetPreorderLockUseCase {
  final ReservationRepository repository;

  SetPreorderLockUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String id,
    required bool open,
  }) {
    return repository.setPreorderLock(id: id, open: open);
  }
}
