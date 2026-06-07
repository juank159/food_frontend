import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/reservation.dart';
import '../repositories/reservation_repository.dart';

/// Update Reservation Use Case
class UpdateReservationUseCase {
  final ReservationRepository repository;

  UpdateReservationUseCase(this.repository);

  Future<Either<Failure, Reservation>> call({
    required String id,
    String? customerName,
    int? partySize,
    DateTime? reservedFor,
    String? customerPhone,
    String? customerEmail,
    String? tableElementId,
    String? floorPlanId,
    int? durationMinutes,
    String? notes,
  }) {
    return repository.updateReservation(
      id: id,
      customerName: customerName,
      partySize: partySize,
      reservedFor: reservedFor,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      tableElementId: tableElementId,
      floorPlanId: floorPlanId,
      durationMinutes: durationMinutes,
      notes: notes,
    );
  }
}
