import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/shift.dart';
import '../../domain/repositories/shift_repository.dart';
import '../datasources/shift_remote_datasource.dart';

class ShiftRepositoryImpl implements ShiftRepository {
  final ShiftRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  ShiftRepositoryImpl({
    required this.remoteDataSource,
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

  @override
  Future<Either<Failure, Shift>> clockIn({String? notes}) {
    return _withNetwork(() async {
      final m = await remoteDataSource.clockIn(notes: notes);
      return m.toEntity();
    });
  }

  @override
  Future<Either<Failure, Shift>> clockOut({String? notes}) {
    return _withNetwork(() async {
      final m = await remoteDataSource.clockOut(notes: notes);
      return m.toEntity();
    });
  }

  @override
  Future<Either<Failure, Shift?>> getMyCurrent() {
    return _withNetwork(() async {
      final m = await remoteDataSource.getMyCurrent();
      return m?.toEntity();
    });
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
