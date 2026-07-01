import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';
import '../datasources/employee_local_datasource.dart';
import '../datasources/employee_remote_datasource.dart';

/// Implementación concreta de `EmployeeRepository`.
///
/// Estrategia cache-first para lecturas:
/// - Online  → fetch remoto, guarda en caché, retorna resultado.
/// - Offline + caché fresca → retorna caché.
/// - Offline sin caché → NetworkFailure.
///
/// Escrituras (create/update/delete) siempre requieren conexión.
class EmployeeRepositoryImpl implements EmployeeRepository {
  final EmployeeRemoteDataSource remoteDataSource;
  final EmployeeLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  EmployeeRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  // ─────────────────────────── Reads (cache-first) ────────────────────────

  @override
  Future<Either<Failure, List<Employee>>> getEmployees({
    EmployeeStatus? status,
    String? roleId,
    String? search,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getEmployees(
          status: status,
          roleId: roleId,
          search: search,
        );
        // Only cache unfiltered requests so the cache represents the full list.
        if (status == null && roleId == null && search == null) {
          await localDataSource
              .cacheEmployees(result.map((m) => m.toJson()).toList());
        }
        return Right(result.map((m) => m.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Employees not found'));
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    }

    // Offline path — try cache.
    final cached = await localDataSource.getCachedEmployees();
    if (cached != null) {
      return Right(cached.map((m) => m.toEntity()).toList());
    }
    return const Left(NetworkFailure());
  }

  @override
  Future<Either<Failure, List<Employee>>> getActiveEmployees() async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getActiveEmployees();
        return Right(result.map((m) => m.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    }

    // Offline: serve cached list filtered to active employees.
    final cached = await localDataSource.getCachedEmployees();
    if (cached != null) {
      final active = cached
          .where((m) => m.status == EmployeeStatus.active.value)
          .map((m) => m.toEntity())
          .toList();
      return Right(active);
    }
    return const Left(NetworkFailure());
  }

  @override
  Future<Either<Failure, Employee>> getEmployeeById(String id) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getEmployeeById(id);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Employee not found'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    }

    // Offline: look up in cached list.
    final cached = await localDataSource.getCachedEmployees();
    if (cached != null) {
      try {
        final found = cached.firstWhere((m) => m.id == id);
        return Right(found.toEntity());
      } catch (_) {
        return const Left(NotFoundFailure('Employee not found'));
      }
    }
    return const Left(NetworkFailure());
  }

  // ────────────────────────── Writes (online-only) ────────────────────────

  @override
  Future<Either<Failure, Employee>> createEmployee({
    required String fullName,
    required String email,
    required String roleId,
    String? phone,
    String? password,
    String? employeeCode,
    EmployeeStatus? status,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      final result = await remoteDataSource.createEmployee(
        fullName: fullName,
        email: email,
        roleId: roleId,
        phone: phone,
        password: password,
        employeeCode: employeeCode,
        status: status,
      );
      return Right(result.toEntity());
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
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
  Future<Either<Failure, Employee>> updateEmployee({
    required String id,
    String? fullName,
    String? email,
    String? phone,
    String? roleId,
    String? employeeCode,
    EmployeeStatus? status,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      final result = await remoteDataSource.updateEmployee(
        id: id,
        fullName: fullName,
        email: email,
        phone: phone,
        roleId: roleId,
        employeeCode: employeeCode,
        status: status,
      );
      return Right(result.toEntity());
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on NotFoundException {
      return const Left(NotFoundFailure('Employee not found'));
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
  Future<Either<Failure, Employee>> suspendEmployee(String id) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      final result = await remoteDataSource.suspendEmployee(id);
      return Right(result.toEntity());
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on NotFoundException {
      return const Left(NotFoundFailure('Employee not found'));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Employee>> activateEmployee(String id) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      final result = await remoteDataSource.activateEmployee(id);
      return Right(result.toEntity());
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on NotFoundException {
      return const Left(NotFoundFailure('Employee not found'));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteEmployee(String id) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      await remoteDataSource.deleteEmployee(id);
      return const Right(null);
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on NotFoundException {
      return const Left(NotFoundFailure('Employee not found'));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
