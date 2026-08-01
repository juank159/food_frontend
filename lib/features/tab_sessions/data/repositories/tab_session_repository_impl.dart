// lib features/tab_sessions/data/repositories/tab_session_repository_impl.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/tab_session.dart';
import '../../domain/repositories/tab_session_repository.dart';
import '../datasources/tab_session_remote_datasource.dart';

class TabSessionRepositoryImpl implements TabSessionRepository {
  final TabSessionRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  TabSessionRepositoryImpl({
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
  Future<Either<Failure, TabSession>> open({
    String? tableElementId,
    String? tableId,
    String? customerId,
    int? partySize,
    String? notes,
  }) {
    return _run(() async {
      final model = await remoteDataSource.open({
        if (tableElementId != null) 'table_element_id': tableElementId,
        if (tableId != null) 'table_id': tableId,
        if (customerId != null) 'customer_id': customerId,
        if (partySize != null) 'party_size': partySize,
        if (notes != null) 'notes': notes,
      });
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, List<TabSession>>> findOpen() {
    return _run(() async {
      final list = await remoteDataSource.findOpen();
      return list.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, TabSession>> findOne(String id) {
    return _run(() async {
      final model = await remoteDataSource.findOne(id);
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, TabSession>> update(
    String id, {
    String? customerName,
    String? notes,
    int? partySize,
  }) {
    return _run(() async {
      final body = <String, dynamic>{};
      if (customerName != null) body['customer_name'] = customerName;
      if (notes != null) body['notes'] = notes;
      if (partySize != null) body['party_size'] = partySize;
      final model = await remoteDataSource.update(id, body);
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, TabSession>> close({
    required String id,
    bool force = false,
    String? notes,
  }) {
    return _run(() async {
      final model = await remoteDataSource.close(id, {
        'force': force,
        if (notes != null) 'notes': notes,
      });
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, void>> voidSession(String id) {
    return _run(() => remoteDataSource.voidSession(id));
  }
}
