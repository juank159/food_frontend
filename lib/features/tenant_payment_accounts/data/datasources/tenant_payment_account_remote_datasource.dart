import 'package:dio/dio.dart';
import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/error/exceptions.dart';
import '../models/tenant_payment_account_model.dart';

abstract class TenantPaymentAccountRemoteDataSource {
  Future<List<TenantPaymentAccountModel>> getAll({
    PaymentMethod? category,
    bool? onlyActive,
  });

  Future<TenantPaymentAccountModel> getById(String id);

  Future<TenantPaymentAccountModel> create(Map<String, dynamic> body);

  Future<TenantPaymentAccountModel> update(
    String id,
    Map<String, dynamic> body,
  );

  Future<TenantPaymentAccountModel> toggleActive(String id);

  Future<void> delete(String id);
}

class TenantPaymentAccountRemoteDataSourceImpl
    implements TenantPaymentAccountRemoteDataSource {
  final Dio dio;

  TenantPaymentAccountRemoteDataSourceImpl({required this.dio});

  Map<String, dynamic> _extractObject(Response response) {
    final raw = response.data;
    if (raw is Map<String, dynamic>) {
      final inner = raw['data'];
      if (inner is Map<String, dynamic>) return inner;
      return raw;
    }
    throw ServerException(
      'Formato de respuesta inesperado: ${raw.runtimeType}',
    );
  }

  List<dynamic> _extractList(Response response) {
    final raw = response.data;
    if (raw is List) return raw;
    if (raw is Map<String, dynamic>) {
      final inner = raw['data'];
      if (inner is List) return inner;
      if (inner is Map<String, dynamic>) {
        final nested = inner['data'];
        if (nested is List) return nested;
      }
    }
    throw ServerException(
      'Formato de respuesta inesperado (lista): ${raw.runtimeType}',
    );
  }

  @override
  Future<List<TenantPaymentAccountModel>> getAll({
    PaymentMethod? category,
    bool? onlyActive,
  }) async {
    try {
      final response = await dio.get(
        ApiConstants.tenantPaymentAccounts,
        queryParameters: {
          if (category != null) 'category': category.value,
          if (onlyActive != null) 'only_active': onlyActive,
        },
      );
      return _extractList(response)
          .whereType<Map<String, dynamic>>()
          .map(TenantPaymentAccountModel.fromJson)
          .toList();
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  @override
  Future<TenantPaymentAccountModel> getById(String id) async {
    try {
      final response =
          await dio.get(ApiConstants.tenantPaymentAccountById(id));
      return TenantPaymentAccountModel.fromJson(_extractObject(response));
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  @override
  Future<TenantPaymentAccountModel> create(Map<String, dynamic> body) async {
    try {
      final response = await dio.post(
        ApiConstants.tenantPaymentAccounts,
        data: body,
      );
      return TenantPaymentAccountModel.fromJson(_extractObject(response));
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  @override
  Future<TenantPaymentAccountModel> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await dio.put(
        ApiConstants.tenantPaymentAccountById(id),
        data: body,
      );
      return TenantPaymentAccountModel.fromJson(_extractObject(response));
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  @override
  Future<TenantPaymentAccountModel> toggleActive(String id) async {
    try {
      final response =
          await dio.patch(ApiConstants.toggleTenantPaymentAccount(id));
      return TenantPaymentAccountModel.fromJson(_extractObject(response));
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await dio.delete(ApiConstants.tenantPaymentAccountById(id));
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
        return ValidationException(msg ?? 'Cuenta duplicada');
      case 500:
        return ServerException(msg ?? 'Error del servidor');
      default:
        return NetworkException(error.message ?? 'Error de red');
    }
  }
}
