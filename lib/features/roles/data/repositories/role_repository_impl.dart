import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/services/local_cache_service.dart';
import '../../domain/entities/role.dart';
import '../../domain/repositories/role_repository.dart';
import '../datasources/role_remote_datasource.dart';
import '../models/role_model.dart';

class RoleRepositoryImpl implements RoleRepository {
  final RoleRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;
  final LocalCacheService localCache;

  RoleRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
    required this.localCache,
  });

  Future<Either<Failure, T>> _wrap<T>(Future<T> Function() action) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure('Sin conexión a internet'));
    }
    try {
      return Right(await action());
    } on AppException catch (e) {
      return Left(_fromException(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Failure _fromException(AppException e) {
    if (e is ServerException) return ServerFailure(e.message);
    if (e is ValidationException) return ValidationFailure(e.message);
    if (e is UnauthorizedException) return UnauthorizedFailure(e.message);
    if (e is NotFoundException) return NotFoundFailure(e.message);
    if (e is NetworkException) return NetworkFailure(e.message);
    return ServerFailure(e.message);
  }

  /// Los roles cambian rarísima vez (solo cuando un admin edita
  /// permisos) — local-first: si no hay red, cae a la caché sin
  /// importar su edad, en vez de bloquear pantallas que necesitan
  /// saber los roles (ej. asignar un rol a un empleado).
  @override
  Future<Either<Failure, List<Role>>> findAll() async {
    if (await networkInfo.isConnected) {
      try {
        final list = await remoteDataSource.findAll();
        await localCache.saveList(
          CacheKeys.roles,
          list.map((m) => m.toJson()).toList(),
        );
        return Right(list.map((m) => m.toEntity()).toList());
      } on AppException catch (e) {
        return Left(_fromException(e));
      } catch (e) {
        return Left(ServerFailure(e.toString()));
      }
    }

    final raw = localCache.getList(CacheKeys.roles);
    if (raw == null) return Left(NetworkFailure('Sin conexión a internet'));
    return Right(raw.map((j) => RoleModel.fromJson(j).toEntity()).toList());
  }

  @override
  Future<Either<Failure, Role>> findOne(String id) {
    return _wrap(() async => (await remoteDataSource.findOne(id)).toEntity());
  }

  @override
  Future<Either<Failure, Role>> create({
    required String name,
    required String code,
    required Map<String, List<String>> permissions,
    String? description,
    bool? isActive,
    int? sortOrder,
  }) {
    return _wrap(() async {
      final body = <String, dynamic>{
        'name': name,
        'code': code,
        'permissions': permissions,
        if (description != null) 'description': description,
        if (isActive != null) 'is_active': isActive,
        if (sortOrder != null) 'sort_order': sortOrder,
      };
      return (await remoteDataSource.create(body)).toEntity();
    });
  }

  @override
  Future<Either<Failure, Role>> update(
    String id, {
    String? name,
    String? description,
    Map<String, List<String>>? permissions,
    bool? isActive,
    int? sortOrder,
  }) {
    return _wrap(() async {
      final body = <String, dynamic>{
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (permissions != null) 'permissions': permissions,
        if (isActive != null) 'is_active': isActive,
        if (sortOrder != null) 'sort_order': sortOrder,
      };
      return (await remoteDataSource.update(id, body)).toEntity();
    });
  }

  @override
  Future<Either<Failure, void>> remove(String id) {
    return _wrap(() => remoteDataSource.remove(id));
  }
}
