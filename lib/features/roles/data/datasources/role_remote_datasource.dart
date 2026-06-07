import 'package:dio/dio.dart';

import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../models/role_model.dart';

abstract class RoleRemoteDataSource {
  Future<List<RoleModel>> findAll();
  Future<RoleModel> findOne(String id);
  Future<RoleModel> create(Map<String, dynamic> body);
  Future<RoleModel> update(String id, Map<String, dynamic> body);
  Future<void> remove(String id);
}

class RoleRemoteDataSourceImpl implements RoleRemoteDataSource {
  final Dio dio;
  RoleRemoteDataSourceImpl({required this.dio});

  Map<String, dynamic> _obj(Response r) {
    final raw = r.data;
    if (raw is Map<String, dynamic>) {
      final inner = raw['data'];
      if (inner is Map<String, dynamic>) return inner;
      return raw;
    }
    throw ServerException('Formato inesperado: ${raw.runtimeType}');
  }

  List<dynamic> _list(Response r) {
    final raw = r.data;
    if (raw is List) return raw;
    if (raw is Map<String, dynamic>) {
      final inner = raw['data'];
      if (inner is List) return inner;
    }
    throw ServerException('Formato lista inesperado: ${raw.runtimeType}');
  }

  @override
  Future<List<RoleModel>> findAll() async {
    try {
      final r = await dio.get(ApiConstants.roles);
      return _list(r).whereType<Map<String, dynamic>>().map(RoleModel.fromJson).toList();
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  @override
  Future<RoleModel> findOne(String id) async {
    try {
      final r = await dio.get(ApiConstants.roleById(id));
      return RoleModel.fromJson(_obj(r));
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  @override
  Future<RoleModel> create(Map<String, dynamic> body) async {
    try {
      final r = await dio.post(ApiConstants.roles, data: body);
      return RoleModel.fromJson(_obj(r));
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  @override
  Future<RoleModel> update(String id, Map<String, dynamic> body) async {
    try {
      final r = await dio.patch(ApiConstants.roleById(id), data: body);
      return RoleModel.fromJson(_obj(r));
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  @override
  Future<void> remove(String id) async {
    try {
      await dio.delete(ApiConstants.roleById(id));
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  Exception _handle(DioException error) {
    final data = error.response?.data;
    String? msg;
    if (data is Map<String, dynamic>) msg = data['message']?.toString();
    switch (error.response?.statusCode) {
      case 400:
        return ValidationException(msg ?? 'Datos inválidos');
      case 401:
      case 403:
        return UnauthorizedException();
      case 404:
        return NotFoundException(msg ?? 'Rol no encontrado');
      case 409:
        return ValidationException(msg ?? 'Conflicto');
      case 500:
        return ServerException(msg ?? 'Error del servidor');
      default:
        return NetworkException(error.message ?? 'Error de red');
    }
  }
}
