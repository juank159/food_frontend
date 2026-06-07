import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/reservation.dart';
import '../repositories/reservation_repository.dart';

/// Get Reservation By Id Use Case
class GetReservationByIdUseCase {
  final ReservationRepository repository;

  GetReservationByIdUseCase(this.repository);

  Future<Either<Failure, Reservation>> call(String id) {
    return repository.getReservationById(id);
  }
}
