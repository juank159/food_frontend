import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/reservation_enums.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/reservation.dart';
import '../../domain/repositories/reservation_repository.dart';
import '../datasources/reservation_remote_datasource.dart';

/// Reservation Repository Implementation.
///
/// Mapea excepciones del datasource a `Failure`s del dominio. Mismo
/// patrón que `CustomerRepositoryImpl` y `OrderRepositoryImpl`.
class ReservationRepositoryImpl implements ReservationRepository {
  final ReservationRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  ReservationRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      final result = await action();
      return Right(result);
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on ConflictException catch (e) {
      return Left(ConflictFailure(e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Reservation>>> getReservations({
    ReservationStatus? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? search,
    int? page,
    int? limit,
  }) {
    return _guard(() async {
      final result = await remoteDataSource.getReservations(
        status: status,
        dateFrom: dateFrom,
        dateTo: dateTo,
        search: search,
        page: page,
        limit: limit,
      );
      return result.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, List<Reservation>>> getUpcomingReservations({
    int hours = 24,
  }) {
    return _guard(() async {
      final result =
          await remoteDataSource.getUpcomingReservations(hours: hours);
      return result.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, Reservation>> getReservationById(String id) {
    return _guard(() async {
      final result = await remoteDataSource.getReservationById(id);
      return result.toEntity();
    });
  }

  @override
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
  }) {
    return _guard(() async {
      final result = await remoteDataSource.createReservation(
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
      return result.toEntity();
    });
  }

  @override
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
  }) {
    return _guard(() async {
      final result = await remoteDataSource.updateReservation(
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
      return result.toEntity();
    });
  }

  @override
  Future<Either<Failure, Reservation>> updateReservationStatus({
    required String id,
    required ReservationStatus status,
    String? notes,
  }) {
    return _guard(() async {
      final result = await remoteDataSource.updateReservationStatus(
        id: id,
        status: status,
        notes: notes,
      );
      return result.toEntity();
    });
  }

  @override
  Future<Either<Failure, Reservation>> cancelReservation({
    required String id,
    String? reason,
  }) {
    return _guard(() async {
      final result =
          await remoteDataSource.cancelReservation(id: id, reason: reason);
      return result.toEntity();
    });
  }

  @override
  Future<Either<Failure, void>> deleteReservation(String id) {
    return _guard(() => remoteDataSource.deleteReservation(id));
  }
}
