import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/reservation.dart';
import '../repositories/reservation_repository.dart';

/// Cancel Reservation Use Case
/// Cancela una reserva con razón opcional (queda guardada en `notes`).
class CancelReservationUseCase {
  final ReservationRepository repository;

  CancelReservationUseCase(this.repository);

  Future<Either<Failure, Reservation>> call({
    required String id,
    String? reason,
  }) {
    return repository.cancelReservation(id: id, reason: reason);
  }
}
