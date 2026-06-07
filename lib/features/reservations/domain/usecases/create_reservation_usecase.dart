import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/reservation.dart';
import '../repositories/reservation_repository.dart';

/// Create Reservation Use Case
class CreateReservationUseCase {
  final ReservationRepository repository;

  CreateReservationUseCase(this.repository);

  Future<Either<Failure, Reservation>> call({
    required String customerName,
    required int partySize,
    required DateTime reservedFor,
    String? customerPhone,
    String? customerEmail,
    String? customerId,
    String? tableElementId,
    String? floorPlanId,
    int? durationMinutes,
    String? notes,
  }) {
    return repository.createReservation(
      customerName: customerName,
      partySize: partySize,
      reservedFor: reservedFor,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      customerId: customerId,
      tableElementId: tableElementId,
      floorPlanId: floorPlanId,
      durationMinutes: durationMinutes,
      notes: notes,
    );
  }
}
