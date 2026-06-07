import 'package:dio/dio.dart';

import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../models/shift_model.dart';

abstract class ShiftRemoteDataSource {
  Future<ShiftModel> clockIn({String? notes});
  Future<ShiftModel> clockOut({String? notes});

  /// El turno actual del usuario logueado. Null si no tiene uno abierto.
  Future<ShiftModel?> getMyCurrent();

  /// Histórico del usuario logueado.
  Future<List<ShiftModel>> getMine({
    DateTime? from,
    DateTime? to,
    int? limit,
  });

  /// Empleados con turno abierto ahora — solo admin/manager.
  Future<List<ShiftModel>> getActiveStaff();
}

class ShiftRemoteDataSourceImpl implements ShiftRemoteDataSource {
  final Dio dio;

  ShiftRemoteDataSourceImpl({required this.dio});

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
  Future<ShiftModel> clockIn({String? notes}) async {
    try {
      final response = await dio.post(
        ApiConstants.shiftClockIn,
        data: {if (notes != null && notes.isNotEmpty) 'notes': notes},
      );
      return ShiftModel.fromJson(_extractObject(response));
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  @override
  Future<ShiftModel> clockOut({String? notes}) async {
    try {
      final response = await dio.post(
        ApiConstants.shiftClockOut,
        data: {if (notes != null && notes.isNotEmpty) 'notes': notes},
      );
      return ShiftModel.fromJson(_extractObject(response));
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  @override
  Future<ShiftModel?> getMyCurrent() async {
    try {
      final response = await dio.get(ApiConstants.shiftMyCurrent);
      // Backend devuelve el objeto plano o null si no hay turno abierto.
      final raw = response.data;
      if (raw == null) return null;
      if (raw is Map<String, dynamic>) {
        if (raw.containsKey('data') && !raw.containsKey('id')) {
          final inner = raw['data'];
          if (inner is Map<String, dynamic>) {
            return ShiftModel.fromJson(inner);
          }
          return null;
        }
        if (raw.containsKey('id')) {
          return ShiftModel.fromJson(raw);
        }
      }
      return null;
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  @override
  Future<List<ShiftModel>> getMine({
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (from != null) query['from'] = from.toIso8601String();
      if (to != null) query['to'] = to.toIso8601String();
      if (limit != null) query['limit'] = limit;

      final response = await dio.get(
        ApiConstants.shiftMine,
        queryParameters: query,
      );
      return _extractList(response)
          .whereType<Map<String, dynamic>>()
          .map(ShiftModel.fromJson)
          .toList();
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  @override
  Future<List<ShiftModel>> getActiveStaff() async {
    try {
      final response = await dio.get(ApiConstants.shiftActive);
      return _extractList(response)
          .whereType<Map<String, dynamic>>()
          .map(ShiftModel.fromJson)
          .toList();
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
      case 403:
        return UnauthorizedException();
      case 404:
        return NotFoundException(msg ?? 'Turno no encontrado');
      case 409:
        return ValidationException(msg ?? 'Ya tenés un turno abierto');
      case 500:
        return ServerException(msg ?? 'Error del servidor');
      default:
        return NetworkException(error.message ?? 'Error de red');
    }
  }
}
