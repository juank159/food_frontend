import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/reservation_enums.dart';
import '../../../../core/error/failures.dart';
import '../entities/reservation.dart';
import '../repositories/reservation_repository.dart';

/// Get Reservations Use Case
/// Obtiene reservaciones con filtros opcionales (status, fecha, búsqueda).
class GetReservationsUseCase {
  final ReservationRepository repository;

  GetReservationsUseCase(this.repository);

  Future<Either<Failure, List<Reservation>>> call({
    ReservationStatus? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? search,
    int? page,
    int? limit,
  }) {
    return repository.getReservations(
      status: status,
      dateFrom: dateFrom,
      dateTo: dateTo,
      search: search,
      page: page,
      limit: limit,
    );
  }
}
