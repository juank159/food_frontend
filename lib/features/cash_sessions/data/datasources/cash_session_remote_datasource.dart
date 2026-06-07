import 'package:dio/dio.dart';
import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../models/cash_session_model.dart';

abstract class CashSessionRemoteDataSource {
  Future<CashSessionModel> open(Map<String, dynamic> body);
  Future<CashSessionModel?> getCurrent();
  Future<CashSessionModel> findOne(String id);
  Future<List<CashSessionModel>> findAll(Map<String, dynamic> query);
  Future<Map<String, dynamic>> getReport(String id);
  Future<CashSessionModel> close(String id, Map<String, dynamic> body);
  Future<void> voidSession(String id);
}

class CashSessionRemoteDataSourceImpl implements CashSessionRemoteDataSource {
  final Dio dio;

  CashSessionRemoteDataSourceImpl({required this.dio});

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
  Future<CashSessionModel> open(Map<String, dynamic> body) async {
    try {
      final response =
          await dio.post(ApiConstants.cashSessionOpen, data: body);
      return CashSessionModel.fromJson(_extractObject(response));
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  @override
  Future<CashSessionModel?> getCurrent() async {
    try {
      final response = await dio.get(ApiConstants.cashSessionCurrent);
      // El endpoint devuelve:
      //   - El objeto CashSession plano `{id, status, ...}` si hay sesión.
      //   - `null` si no hay sesión abierta.
      //   - Algunos clients/proxys envuelven en `{data: ...}` — toleramos
      //     ambas formas.
      final raw = response.data;
      if (raw == null) return null;
      if (raw is! Map<String, dynamic>) return null;

      // Caso envuelto: `{data: {...}}` o `{data: null}`.
      if (raw.containsKey('data') && !raw.containsKey('id')) {
        final inner = raw['data'];
        if (inner == null) return null;
        if (inner is Map<String, dynamic>) {
          return CashSessionModel.fromJson(inner);
        }
        return null;
      }

      // Caso plano: el body ES la sesión (lo que devuelve el backend hoy).
      if (raw.containsKey('id')) {
        return CashSessionModel.fromJson(raw);
      }

      // Body con forma inesperada — tratamos como "sin sesión" en vez de
      // crashear.
      return null;
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  @override
  Future<CashSessionModel> findOne(String id) async {
    try {
      final response = await dio.get(ApiConstants.cashSessionById(id));
      return CashSessionModel.fromJson(_extractObject(response));
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  @override
  Future<List<CashSessionModel>> findAll(Map<String, dynamic> query) async {
    try {
      final response = await dio.get(
        ApiConstants.cashSessions,
        queryParameters: query,
      );
      return _extractList(response)
          .whereType<Map<String, dynamic>>()
          .map(CashSessionModel.fromJson)
          .toList();
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  @override
  Future<Map<String, dynamic>> getReport(String id) async {
    try {
      final response = await dio.get(ApiConstants.cashSessionReport(id));
      final raw = response.data;
      if (raw is Map<String, dynamic>) {
        // El endpoint devuelve `{ session, cash_payments, by_method }`
        // que es lo que necesitamos. Si viniera anidado en `data`,
        // desempacamos.
        final inner = raw['data'];
        if (inner is Map<String, dynamic>) return inner;
        return raw;
      }
      throw ServerException('Reporte con formato inesperado');
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  @override
  Future<CashSessionModel> close(
    String id,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await dio.patch(
        ApiConstants.closeCashSession(id),
        data: body,
      );
      return CashSessionModel.fromJson(_extractObject(response));
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  @override
  Future<void> voidSession(String id) async {
    try {
      await dio.delete(ApiConstants.cashSessionById(id));
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  Exception _handle(DioException error) {
    final data = error.response?.data;
    String? msg;
    Map<String, dynamic>? details;
    if (data is Map<String, dynamic>) {
      // Puede ser un mensaje string o un objeto detallado (cierre con
      // diferencia grande devuelve un objeto con expected/counted/etc).
      final m = data['message'];
      if (m is String) {
        msg = m;
      } else if (m is Map<String, dynamic>) {
        msg = m['message']?.toString();
        details = m;
      }
    }
    switch (error.response?.statusCode) {
      case 400:
        // Si hay detalles de diferencia, pasamos un mensaje
        // estructurado que la UI puede parsear.
        if (details != null) {
          return ValidationException(
            'CASH_DIFFERENCE:${msg ?? "diferencia significativa"}',
          );
        }
        return ValidationException(msg ?? 'Datos inválidos');
      case 401:
        return UnauthorizedException();
      case 403:
        return UnauthorizedException();
      case 404:
        return NotFoundException(msg ?? 'Sesión no encontrada');
      case 409:
        return ValidationException(
          msg ?? 'Ya tenés una caja abierta',
        );
      case 500:
        return ServerException(msg ?? 'Error del servidor');
      default:
        return NetworkException(error.message ?? 'Error de red');
    }
  }
}
