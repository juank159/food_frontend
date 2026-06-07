import 'package:dio/dio.dart';
import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/employee.dart';
import '../models/employee_model.dart';

/// Fuente de datos remota para empleados.
///
/// El backend expone los empleados bajo `/users` — esta capa traduce el
/// vocabulario para que el resto del feature hable de "empleados".
abstract class EmployeeRemoteDataSource {
  Future<List<EmployeeModel>> getEmployees({
    EmployeeStatus? status,
    String? roleId,
    String? search,
  });

  Future<List<EmployeeModel>> getActiveEmployees();

  Future<EmployeeModel> getEmployeeById(String id);

  Future<EmployeeModel> createEmployee({
    required String fullName,
    required String email,
    required String roleId,
    String? phone,
    String? password,
    String? employeeCode,
    EmployeeStatus? status,
  });

  Future<EmployeeModel> updateEmployee({
    required String id,
    String? fullName,
    String? email,
    String? phone,
    String? roleId,
    String? employeeCode,
    EmployeeStatus? status,
  });

  Future<EmployeeModel> suspendEmployee(String id);

  Future<EmployeeModel> activateEmployee(String id);

  Future<void> deleteEmployee(String id);
}

class EmployeeRemoteDataSourceImpl implements EmployeeRemoteDataSource {
  final Dio dio;

  EmployeeRemoteDataSourceImpl({required this.dio});

  // ─────────────────────────── Read ───────────────────────────

  @override
  Future<List<EmployeeModel>> getEmployees({
    EmployeeStatus? status,
    String? roleId,
    String? search,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (status != null) query['status'] = status.value;
      if (roleId != null && roleId.isNotEmpty) query['role_id'] = roleId;
      if (search != null && search.isNotEmpty) query['search'] = search;

      final response = await dio.get(
        ApiConstants.users,
        queryParameters: query,
      );
      return _parseList(response, 'Failed to load employees');
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<List<EmployeeModel>> getActiveEmployees() async {
    try {
      final response = await dio.get('${ApiConstants.users}/active');
      return _parseList(response, 'Failed to load active employees');
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<EmployeeModel> getEmployeeById(String id) async {
    try {
      final response = await dio.get(ApiConstants.userById(id));
      return _parseSingle(response, 'Failed to load employee');
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  // ─────────────────────────── Write ───────────────────────────

  @override
  Future<EmployeeModel> createEmployee({
    required String fullName,
    required String email,
    required String roleId,
    String? phone,
    String? password,
    String? employeeCode,
    EmployeeStatus? status,
  }) async {
    try {
      final body = <String, dynamic>{
        'full_name': fullName,
        'email': email,
        'role_id': roleId,
      };
      if (phone != null && phone.isNotEmpty) body['phone'] = phone;
      if (password != null && password.isNotEmpty) body['password'] = password;
      if (employeeCode != null && employeeCode.isNotEmpty) {
        body['employee_code'] = employeeCode;
      }
      if (status != null) body['status'] = status.value;

      final response = await dio.post(ApiConstants.users, data: body);
      return _parseSingle(response, 'Failed to create employee');
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<EmployeeModel> updateEmployee({
    required String id,
    String? fullName,
    String? email,
    String? phone,
    String? roleId,
    String? employeeCode,
    EmployeeStatus? status,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (fullName != null) body['full_name'] = fullName;
      if (email != null) body['email'] = email;
      if (phone != null) body['phone'] = phone;
      if (roleId != null) body['role_id'] = roleId;
      if (employeeCode != null) body['employee_code'] = employeeCode;
      if (status != null) body['status'] = status.value;

      final response = await dio.patch(
        ApiConstants.userById(id),
        data: body,
      );
      return _parseSingle(response, 'Failed to update employee');
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<EmployeeModel> suspendEmployee(String id) async {
    try {
      final response = await dio.patch('${ApiConstants.userById(id)}/suspend');
      return _parseSingle(response, 'Failed to suspend employee');
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<EmployeeModel> activateEmployee(String id) async {
    try {
      final response = await dio.patch('${ApiConstants.userById(id)}/activate');
      return _parseSingle(response, 'Failed to activate employee');
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<void> deleteEmployee(String id) async {
    try {
      final response = await dio.delete(ApiConstants.userById(id));
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ServerException('Failed to delete employee');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  // ─────────────────────────── Helpers ───────────────────────────

  /// Parsea una respuesta que puede venir como `List`, como `{data: [...]}`
  /// o como `{data: {...}}` (algunos endpoints `active` envuelven distinto).
  List<EmployeeModel> _parseList(Response response, String errorMessage) {
    if (response.statusCode != 200) throw ServerException(errorMessage);
    final raw = response.data;
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(EmployeeModel.fromJson)
          .toList();
    }
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(EmployeeModel.fromJson)
            .toList();
      }
    }
    throw ServerException('Invalid response format');
  }

  EmployeeModel _parseSingle(Response response, String errorMessage) {
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ServerException(errorMessage);
    }
    final raw = response.data;
    if (raw is Map<String, dynamic>) {
      final candidate = raw['data'] ?? raw;
      if (candidate is Map<String, dynamic>) {
        return EmployeeModel.fromJson(candidate);
      }
    }
    throw ServerException('Invalid response format');
  }

  void _handleDioException(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401) {
      throw UnauthorizedException('Unauthorized');
    } else if (status == 404) {
      throw NotFoundException('Employee not found');
    } else if (status == 409) {
      throw ConflictException(_extractMessage(e) ?? 'Email already in use');
    } else if (status == 400) {
      throw ValidationException(_extractMessage(e) ?? 'Bad request');
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw NetworkException('Connection timeout');
    } else if (e.type == DioExceptionType.unknown) {
      throw NetworkException('Network error: ${e.message}');
    } else {
      throw ServerException(_extractMessage(e) ?? 'Server error occurred');
    }
  }

  String? _extractMessage(DioException e) {
    final raw = e.response?.data;
    if (raw is Map<String, dynamic>) {
      final message = raw['message'];
      if (message is List) return message.join(', ');
      if (message is String) return message;
    }
    return null;
  }
}
