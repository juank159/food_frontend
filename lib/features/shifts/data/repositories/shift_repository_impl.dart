import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/shift.dart';
import '../../domain/repositories/shift_repository.dart';
import '../datasources/shift_local_datasource.dart';
import '../datasources/shift_remote_datasource.dart';
import '../models/shift_model.dart';

class ShiftRepositoryImpl implements ShiftRepository {
  final ShiftRemoteDataSource remoteDataSource;
  final ShiftLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  ShiftRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  Future<Either<Failure, T>> _withNetwork<T>(
    Future<T> Function() action,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure('Sin conexión a internet'));
    }
    try {
      return Right(await action());
    } on AppException catch (e) {
      return Left(_failureFromException(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Failure _failureFromException(AppException e) {
    if (e is ServerException) return ServerFailure(e.message);
    if (e is ValidationException) return ValidationFailure(e.message);
    if (e is UnauthorizedException) return UnauthorizedFailure(e.message);
    if (e is NotFoundException) return NotFoundFailure(e.message);
    if (e is NetworkException) return NetworkFailure(e.message);
    return ServerFailure(e.message);
  }

  /// A diferencia de crear un producto/una cuenta, fichar no genera un
  /// ID que algo más vaya a referenciar antes de sincronizar — es un
  /// evento de una sola vez. Por eso SÍ se encola offline (como
  /// createOrder), con un Shift optimista local mientras se sincroniza.
  @override
  Future<Either<Failure, Shift>> clockIn({String? notes}) async {
    if (await networkInfo.isConnected) {
      try {
        final m = await remoteDataSource.clockIn(notes: notes);
        await localDataSource.clearPendingShift();
        return Right(m.toEntity());
      } on AppException catch (e) {
        return Left(_failureFromException(e));
      } catch (e) {
        return Left(ServerFailure(e.toString()));
      }
    }

    final now = DateTime.now().toIso8601String();
    final optimistic = ShiftModel(
      id: 'local_${const Uuid().v4()}',
      // El id real del usuario no importa acá — es un valor local que
      // solo se usa para que `getMyCurrent()` tenga algo que mostrar
      // mientras se sincroniza. `getMine()`/getActiveStaff() (lo que sí
      // necesita el id real) siempre va por red.
      userId: 'me',
      clockIn: now,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
    await localDataSource.savePendingShift(optimistic);
    await localDataSource.enqueueClockIn({
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return Right(optimistic.toEntity());
  }

  @override
  Future<Either<Failure, Shift>> clockOut({String? notes}) async {
    if (await networkInfo.isConnected) {
      try {
        final m = await remoteDataSource.clockOut(notes: notes);
        await localDataSource.clearPendingShift();
        return Right(m.toEntity());
      } on AppException catch (e) {
        return Left(_failureFromException(e));
      } catch (e) {
        return Left(ServerFailure(e.toString()));
      }
    }

    // Cierra el shift optimista que haya (del clock-in encolado, o el
    // último conocido) — igual se encola el clock-out real para
    // cuando vuelva la señal.
    final pending = await localDataSource.getPendingShift();
    final now = DateTime.now().toIso8601String();
    final closed = ShiftModel(
      id: pending?.id ?? 'local_${const Uuid().v4()}',
      userId: pending?.userId ?? 'me',
      clockIn: pending?.clockIn ?? now,
      clockOut: now,
      notes: notes ?? pending?.notes,
      createdAt: pending?.createdAt ?? now,
      updatedAt: now,
    );
    await localDataSource.savePendingShift(closed);
    await localDataSource.enqueueClockOut({
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return Right(closed.toEntity());
  }

  /// Si no hay red, refleja el Shift optimista local (si hay un
  /// clock-in pendiente de sincronizar) en vez de fallar directo —
  /// para que la pantalla de fichaje siga mostrando "estás en turno"
  /// aunque la red se haya caído después de fichar.
  @override
  Future<Either<Failure, Shift?>> getMyCurrent() async {
    if (await networkInfo.isConnected) {
      try {
        final m = await remoteDataSource.getMyCurrent();
        return Right(m?.toEntity());
      } on AppException catch (e) {
        return Left(_failureFromException(e));
      } catch (e) {
        return Left(ServerFailure(e.toString()));
      }
    }

    final pending = await localDataSource.getPendingShift();
    if (pending == null) return const Right(null);
    // Si el pending ya tiene clock_out, significa que el último
    // evento offline fue "salida" — no hay turno abierto.
    return Right(pending.clockOut == null ? pending.toEntity() : null);
  }

  @override
  Future<Either<Failure, List<Shift>>> getMine({
    DateTime? from,
    DateTime? to,
    int? limit,
  }) {
    return _withNetwork(() async {
      final list = await remoteDataSource.getMine(
        from: from,
        to: to,
        limit: limit,
      );
      return list.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, List<Shift>>> getActiveStaff() {
    return _withNetwork(() async {
      final list = await remoteDataSource.getActiveStaff();
      return list.map((m) => m.toEntity()).toList();
    });
  }
}
