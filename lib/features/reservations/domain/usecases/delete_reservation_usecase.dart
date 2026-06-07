import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/reservation_repository.dart';

/// Delete Reservation Use Case
/// Soft delete (el backend marca `deleted_at` pero no borra físicamente).
class DeleteReservationUseCase {
  final ReservationRepository repository;

  DeleteReservationUseCase(this.repository);

  Future<Either<Failure, void>> call(String id) {
    return repository.deleteReservation(id);
  }
}
