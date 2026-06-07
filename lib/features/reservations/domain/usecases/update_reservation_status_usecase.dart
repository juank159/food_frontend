import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/reservation_enums.dart';
import '../../../../core/error/failures.dart';
import '../entities/reservation.dart';
import '../repositories/reservation_repository.dart';

/// Update Reservation Status Use Case
///
/// Aplica una transición de estado validada por el backend (la lista de
/// transiciones válidas vive también en `ReservationStatus.nextTransitions`).
class UpdateReservationStatusUseCase {
  final ReservationRepository repository;

  UpdateReservationStatusUseCase(this.repository);

  Future<Either<Failure, Reservation>> call({
    required String id,
    required ReservationStatus status,
    String? notes,
  }) {
    return repository.updateReservationStatus(
      id: id,
      status: status,
      notes: notes,
    );
  }
}
