import 'package:dio/dio.dart';
import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

/// Auth Remote Data Source Interface
abstract class AuthRemoteDataSource {
  Future<AuthResponseModel> login({
    required String email,
    required String password,
    required String tenantSubdomain,
  });

  Future<AuthResponseModel> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phoneNumber,
    required String tenantSubdomain,
  });

  Future<UserModel> getCurrentUser(String token);

  Future<AuthResponseModel> refreshToken(String refreshToken);

  Future<void> logout(String token);
}

/// Auth Remote Data Source Implementation
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;

  AuthRemoteDataSourceImpl({required this.dio});

  @override
  Future<AuthResponseModel> login({
    required String email,
    required String password,
    required String tenantSubdomain,
  }) async {
    try {
      final response = await dio.post(
        ApiConstants.login,
        data: {
          'email': email,
          'password': password,
        },
        options: Options(
          headers: {
            ApiConstants.tenantSubdomainHeader: tenantSubdomain,
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResponseModel.fromJson(response.data);
      } else {
        throw ServerException('Login failed', response.statusCode);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw UnauthorizedException('Invalid credentials');
      } else if (e.response?.statusCode == 404) {
        throw NotFoundException('User not found');
      } else if (e.response?.statusCode == 400) {
        throw ServerException(
          e.response?.data['message'] ?? 'Bad request',
          e.response?.statusCode,
        );
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NetworkException('Connection timeout');
      } else if (e.type == DioExceptionType.unknown) {
        throw NetworkException('No internet connection');
      } else {
        throw ServerException(
          e.response?.data['message'] ?? 'Server error',
          e.response?.statusCode,
        );
      }
    } catch (e) {
      throw ServerException('Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<AuthResponseModel> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phoneNumber,
    required String tenantSubdomain,
  }) async {
    try {
      // Default role for self-service registration. A future selector lets
      // admins assign other roles. Backend requires the role_id to exist in
      // the tenant schema's roles table.
      // TODO(sprint 1.x): replace with a real role selector or invite-based flow.
      const defaultRoleId = '85c0c917-5a17-4ef3-b5f6-159301e827d6'; // waiter role

      final response = await dio.post(
        ApiConstants.register,
        data: {
          'email': email,
          'password': password,
          'full_name': '$firstName $lastName',
          if (phoneNumber != null && phoneNumber.isNotEmpty)
            'phone': phoneNumber,
          'role_id': defaultRoleId,
        },
        options: Options(
          headers: {
            ApiConstants.tenantSubdomainHeader: tenantSubdomain,
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResponseModel.fromJson(response.data);
      } else {
        throw ServerException('Registration failed', response.statusCode);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw ConflictException('Email already exists');
      } else if (e.response?.statusCode == 400) {
        throw ValidationException(
          e.response?.data['message'] ?? 'Validation error',
        );
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NetworkException('Connection timeout');
      } else if (e.type == DioExceptionType.unknown) {
        throw NetworkException('No internet connection');
      } else {
        throw ServerException(
          e.response?.data['message'] ?? 'Server error',
          e.response?.statusCode,
        );
      }
    } catch (e) {
      throw ServerException('Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> getCurrentUser(String token) async {
    try {
      final response = await dio.get(
        ApiConstants.me,
        options: Options(
          headers: {
            ApiConstants.authorizationHeader: 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200) {
        return UserModel.fromJson(response.data);
      } else {
        throw ServerException('Failed to get user', response.statusCode);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw UnauthorizedException('Session expired');
      } else if (e.type == DioExceptionType.unknown) {
        throw NetworkException('No internet connection');
      } else {
        throw ServerException(
          e.response?.data['message'] ?? 'Server error',
          e.response?.statusCode,
        );
      }
    } catch (e) {
      throw ServerException('Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) async {
    try {
      final response = await dio.post(
        ApiConstants.refreshToken,
        data: {
          'refresh_token': refreshToken,
        },
      );

      if (response.statusCode == 200) {
        return AuthResponseModel.fromJson(response.data);
      } else {
        throw ServerException('Token refresh failed', response.statusCode);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw UnauthorizedException('Refresh token expired');
      } else {
        throw ServerException(
          e.response?.data['message'] ?? 'Server error',
          e.response?.statusCode,
        );
      }
    } catch (e) {
      throw ServerException('Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<void> logout(String token) async {
    try {
      await dio.post(
        ApiConstants.logout,
        options: Options(
          headers: {
            ApiConstants.authorizationHeader: 'Bearer $token',
          },
        ),
      );
    } catch (e) {
      // Logout can fail silently
      // The local data will still be cleared
    }
  }
}
