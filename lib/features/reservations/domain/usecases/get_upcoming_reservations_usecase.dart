import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/reservation.dart';
import '../repositories/reservation_repository.dart';

/// Get Upcoming Reservations Use Case
/// Devuelve las reservaciones de las próximas N horas (default 24).
class GetUpcomingReservationsUseCase {
  final ReservationRepository repository;

  GetUpcomingReservationsUseCase(this.repository);

  Future<Either<Failure, List<Reservation>>> call({int hours = 24}) {
    return repository.getUpcomingReservations(hours: hours);
  }
}
