import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/cash_session.dart';
import '../../domain/repositories/cash_session_repository.dart';
import '../datasources/cash_session_remote_datasource.dart';

class CashSessionRepositoryImpl implements CashSessionRepository {
  final CashSessionRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  CashSessionRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  Future<Either<Failure, T>> _run<T>(Future<T> Function() action) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      return Right(await action());
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, CashSession>> open({
    required double openingAmount,
    String? notes,
  }) {
    return _run(() async {
      final model = await remoteDataSource.open({
        'opening_amount': openingAmount,
        if (notes != null) 'notes': notes,
      });
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, CashSession?>> getCurrent() {
    return _run(() async {
      final model = await remoteDataSource.getCurrent();
      return model?.toEntity();
    });
  }

  @override
  Future<Either<Failure, CashSession>> findOne(String id) {
    return _run(() async {
      final model = await remoteDataSource.findOne(id);
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, List<CashSession>>> findAll({
    CashSessionStatus? status,
    String? openedBy,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    return _run(() async {
      final list = await remoteDataSource.findAll({
        if (status != null) 'status': status.value,
        if (openedBy != null) 'opened_by': openedBy,
        if (dateFrom != null) 'date_from': dateFrom.toUtc().toIso8601String(),
        if (dateTo != null) 'date_to': dateTo.toUtc().toIso8601String(),
      });
      return list.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getReport(String id) {
    return _run(() => remoteDataSource.getReport(id));
  }

  @override
  Future<Either<Failure, CashSession>> close({
    required String id,
    required double closingAmountCounted,
    String? closingNotes,
    bool force = false,
  }) {
    return _run(() async {
      final model = await remoteDataSource.close(id, {
        'closing_amount_counted': closingAmountCounted,
        if (closingNotes != null) 'closing_notes': closingNotes,
        'force': force,
      });
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, void>> voidSession(String id) {
    return _run(() => remoteDataSource.voidSession(id));
  }
}
