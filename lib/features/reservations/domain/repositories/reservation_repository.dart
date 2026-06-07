import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/reservation_enums.dart';
import '../../../../core/error/failures.dart';
import '../entities/reservation.dart';

/// Reservation Repository — contrato del dominio.
///
/// Cada método mapea a un endpoint de `reservations.controller.ts`.
abstract class ReservationRepository {
  /// `GET /reservations` con filtros opcionales.
  Future<Either<Failure, List<Reservation>>> getReservations({
    ReservationStatus? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? search,
    int? page,
    int? limit,
  });

  /// `GET /reservations/upcoming?hours=24`.
  Future<Either<Failure, List<Reservation>>> getUpcomingReservations({
    int hours = 24,
  });

  /// `GET /reservations/:id`.
  Future<Either<Failure, Reservation>> getReservationById(String id);

  /// `POST /reservations`.
  Future<Either<Failure, Reservation>> createReservation({
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
  });

  /// `PATCH /reservations/:id` — edición general.
  Future<Either<Failure, Reservation>> updateReservation({
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
  });

  /// `PATCH /reservations/:id/status` — cambio de estado con transición
  /// validada por el backend.
  Future<Either<Failure, Reservation>> updateReservationStatus({
    required String id,
    required ReservationStatus status,
    String? notes,
  });

  /// `POST /reservations/:id/cancel` — cancelación con razón opcional.
  Future<Either<Failure, Reservation>> cancelReservation({
    required String id,
    String? reason,
  });

  /// `DELETE /reservations/:id` — soft delete.
  Future<Either<Failure, void>> deleteReservation(String id);
}
