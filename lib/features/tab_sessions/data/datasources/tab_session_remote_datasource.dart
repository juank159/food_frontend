//lib features/tab_sessions/data/datasources/tab_session_remote_datasource.dart
import 'package:dio/dio.dart';
import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../models/tab_session_model.dart';

abstract class TabSessionRemoteDataSource {
  Future<TabSessionModel> open(Map<String, dynamic> body);
  Future<List<TabSessionModel>> findOpen();
  Future<TabSessionModel> findOne(String id);
  Future<TabSessionModel> update(String id, Map<String, dynamic> body);
  Future<TabSessionModel> close(String id, Map<String, dynamic> body);
  Future<void> voidSession(String id);
}

class TabSessionRemoteDataSourceImpl implements TabSessionRemoteDataSource {
  final Dio dio;

  TabSessionRemoteDataSourceImpl({required this.dio});

  Map<String, dynamic> _extractObject(Response response) {
    final raw = response.data;
    if (raw is Map<String, dynamic>) {
      final inner = raw['data'];
      if (inner is Map<String, dynamic>) return inner;
      return raw;
    }
    throw ServerException('Formato inesperado: ${raw.runtimeType}');
  }

  List<dynamic> _extractList(Response response) {
    final raw = response.data;
    if (raw is List) return raw;
    if (raw is Map<String, dynamic>) {
      final inner = raw['data'];
      if (inner is List) return inner;
    }
    throw ServerException('Formato lista inesperado: ${raw.runtimeType}');
  }

  @override
  Future<TabSessionModel> open(Map<String, dynamic> body) async {
    try {
      final response = await dio.post(ApiConstants.tabSessions, data: body);
      return TabSessionModel.fromJson(_extractObject(response));
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  @override
  Future<List<TabSessionModel>> findOpen() async {
    try {
      final response = await dio.get(ApiConstants.tabSessionsOpen);
      return _extractList(response)
          .whereType<Map<String, dynamic>>()
          .map(TabSessionModel.fromJson)
          .toList();
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  @override
  Future<TabSessionModel> findOne(String id) async {
    try {
      final response = await dio.get(ApiConstants.tabSessionById(id));
      return TabSessionModel.fromJson(_extractObject(response));
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  @override
  Future<TabSessionModel> update(String id, Map<String, dynamic> body) async {
    try {
      final response = await dio.patch(
        ApiConstants.tabSessionById(id),
        data: body,
      );
      return TabSessionModel.fromJson(_extractObject(response));
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  @override
  Future<TabSessionModel> close(String id, Map<String, dynamic> body) async {
    try {
      final response = await dio.patch(
        ApiConstants.closeTabSession(id),
        data: body,
      );
      return TabSessionModel.fromJson(_extractObject(response));
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  @override
  Future<void> voidSession(String id) async {
    try {
      await dio.delete(ApiConstants.tabSessionById(id));
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  Exception _handle(DioException error) {
    final data = error.response?.data;
    String? msg;
    if (data is Map<String, dynamic>) {
      msg = data['message']?.toString();
    }
    switch (error.response?.statusCode) {
      case 400:
        return ValidationException(msg ?? 'Datos inválidos');
      case 401:
        return UnauthorizedException();
      case 404:
        return NotFoundException(msg ?? 'Cuenta no encontrada');
      case 409:
        return ValidationException(msg ?? 'Conflicto');
      case 500:
        return ServerException(msg ?? 'Error del servidor');
      default:
        return NetworkException(error.message ?? 'Error de red');
    }
  }
}
