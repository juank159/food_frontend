import 'package:dio/dio.dart';
import '../../../../core/utils/api_response_utils.dart';
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

  /// `POST /auth/signup` — alta de un negocio NUEVO (tenant + dueño) en
  /// un solo paso. Sin `tenantSubdomain`: todavía no existe ningún
  /// tenant al que apuntar, es justo lo que este endpoint crea. NO
  /// arranca sesión — manda un código de 6 dígitos; hay que confirmarlo
  /// con [confirmSignup] para recién ahí obtener el JWT.
  Future<void> signUp({
    required String businessName,
    required String businessType,
    required String subdomain,
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  });

  /// `POST /auth/signup/confirm` — valida el código de 6 dígitos de
  /// [signUp] y arranca sesión.
  Future<AuthResponseModel> confirmSignup({
    required String email,
    required String code,
  });

  /// `POST /auth/signup/resend-code` — pide un código nuevo cuando el
  /// de [signUp] ya venció (10 min). Siempre "éxito" del lado del
  /// cliente (anti-enumeración).
  Future<void> resendSignupCode({required String email});

  /// `POST /auth/forgot-password` — siempre "éxito" del lado del
  /// cliente (el backend nunca revela si el email existe o no).
  Future<void> forgotPassword({required String email});

  /// `POST /auth/reset-password` — confirma el código de 6 dígitos de
  /// [forgotPassword] y cambia la contraseña.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });

  /// `POST /auth/verify-email` — confirma un email con un código de 6
  /// dígitos SIN arrancar sesión (a diferencia de [confirmSignup]).
  Future<void> verifyEmail({required String email, required String code});

  /// `POST /auth/change-password` (autenticado) — cambia la contraseña
  /// del usuario logueado, verificando la actual.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<UserModel> getCurrentUser(String token);

  Future<AuthResponseModel> refreshToken(String refreshToken);

  Future<void> logout(String token);

  /// `PATCH /users/me` — actualiza el perfil del usuario autenticado.
  /// Los 3 campos son opcionales (solo se envía lo que cambió). El
  /// backend devuelve la entidad `User` cruda del tenant (full_name/
  /// phone, no el shape camelCase de `UserModel`) — por eso este
  /// método no parsea la respuesta, solo confirma que el guardado fue
  /// exitoso; el caller (`AuthRepositoryImpl`) arma el `User` actualizado
  /// localmente con los valores que él mismo mandó.
  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
  });
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
          ApiResponseUtils.errorMessage(e) ?? 'Bad request',
          e.response?.statusCode,
        );
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NetworkException('Connection timeout');
      } else if (e.type == DioExceptionType.unknown) {
        throw NetworkException('No internet connection');
      } else {
        throw ServerException(
          ApiResponseUtils.errorMessage(e) ?? 'Server error',
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
          ApiResponseUtils.errorMessage(e) ?? 'Validation error',
        );
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NetworkException('Connection timeout');
      } else if (e.type == DioExceptionType.unknown) {
        throw NetworkException('No internet connection');
      } else {
        throw ServerException(
          ApiResponseUtils.errorMessage(e) ?? 'Server error',
          e.response?.statusCode,
        );
      }
    } catch (e) {
      throw ServerException('Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<void> signUp({
    required String businessName,
    required String businessType,
    required String subdomain,
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    try {
      final response = await dio.post(
        ApiConstants.signup,
        data: {
          'business_name': businessName,
          'business_type': businessType,
          'subdomain': subdomain,
          'email': email,
          'password': password,
          'full_name': fullName,
          if (phoneNumber != null && phoneNumber.isNotEmpty)
            'phone': phoneNumber,
        },
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException('Signup failed', response.statusCode);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw ConflictException('El subdominio o el email ya están en uso');
      } else if (e.response?.statusCode == 400) {
        throw ValidationException(
          ApiResponseUtils.errorMessage(e) ?? 'Validation error',
        );
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NetworkException('Connection timeout');
      } else if (e.type == DioExceptionType.unknown) {
        throw NetworkException('No internet connection');
      } else {
        throw ServerException(
          ApiResponseUtils.errorMessage(e) ?? 'Server error',
          e.response?.statusCode,
        );
      }
    } catch (e) {
      throw ServerException('Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<AuthResponseModel> confirmSignup({
    required String email,
    required String code,
  }) async {
    try {
      final response = await dio.post(
        ApiConstants.signupConfirm,
        data: {'email': email, 'code': code},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResponseModel.fromJson(response.data);
      } else {
        throw ServerException('Confirmation failed', response.statusCode);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw ValidationException(
          ApiResponseUtils.errorMessage(e) ?? 'Código inválido o expirado',
        );
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NetworkException('Connection timeout');
      } else if (e.type == DioExceptionType.unknown) {
        throw NetworkException('No internet connection');
      } else {
        throw ServerException(
          ApiResponseUtils.errorMessage(e) ?? 'Server error',
          e.response?.statusCode,
        );
      }
    } catch (e) {
      throw ServerException('Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<void> resendSignupCode({required String email}) async {
    try {
      await dio.post(ApiConstants.signupResendCode, data: {'email': email});
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw ValidationException(
          ApiResponseUtils.errorMessage(e) ?? 'Validation error',
        );
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NetworkException('Connection timeout');
      } else if (e.type == DioExceptionType.unknown) {
        throw NetworkException('No internet connection');
      } else {
        throw ServerException(
          ApiResponseUtils.errorMessage(e) ?? 'Server error',
          e.response?.statusCode,
        );
      }
    } catch (e) {
      throw ServerException('Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    try {
      await dio.post(ApiConstants.forgotPassword, data: {'email': email});
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw ValidationException(
          ApiResponseUtils.errorMessage(e) ?? 'Validation error',
        );
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NetworkException('Connection timeout');
      } else if (e.type == DioExceptionType.unknown) {
        throw NetworkException('No internet connection');
      } else {
        throw ServerException(
          ApiResponseUtils.errorMessage(e) ?? 'Server error',
          e.response?.statusCode,
        );
      }
    } catch (e) {
      throw ServerException('Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await dio.post(
        ApiConstants.resetPassword,
        data: {'email': email, 'code': code, 'newPassword': newPassword},
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw ValidationException(
          ApiResponseUtils.errorMessage(e) ?? 'Código inválido o expirado',
        );
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NetworkException('Connection timeout');
      } else if (e.type == DioExceptionType.unknown) {
        throw NetworkException('No internet connection');
      } else {
        throw ServerException(
          ApiResponseUtils.errorMessage(e) ?? 'Server error',
          e.response?.statusCode,
        );
      }
    } catch (e) {
      throw ServerException('Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    try {
      await dio.post(
        ApiConstants.verifyEmail,
        data: {'email': email, 'code': code},
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw ValidationException(
          ApiResponseUtils.errorMessage(e) ?? 'Código inválido o expirado',
        );
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NetworkException('Connection timeout');
      } else if (e.type == DioExceptionType.unknown) {
        throw NetworkException('No internet connection');
      } else {
        throw ServerException(
          ApiResponseUtils.errorMessage(e) ?? 'Server error',
          e.response?.statusCode,
        );
      }
    } catch (e) {
      throw ServerException('Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // Sin headers manuales: el interceptor global de dio ya agrega
      // Authorization a esta ruta (no está en la lista de exclusión de
      // /auth/login|register|refresh).
      await dio.post(
        ApiConstants.changePassword,
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw UnauthorizedException(
          ApiResponseUtils.errorMessage(e) ?? 'La contraseña actual no es correcta',
        );
      } else if (e.response?.statusCode == 400) {
        throw ValidationException(
          ApiResponseUtils.errorMessage(e) ?? 'Validation error',
        );
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NetworkException('Connection timeout');
      } else if (e.type == DioExceptionType.unknown) {
        throw NetworkException('No internet connection');
      } else {
        throw ServerException(
          ApiResponseUtils.errorMessage(e) ?? 'Server error',
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
          ApiResponseUtils.errorMessage(e) ?? 'Server error',
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
          ApiResponseUtils.errorMessage(e) ?? 'Server error',
          e.response?.statusCode,
        );
      }
    } catch (e) {
      throw ServerException('Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
  }) async {
    try {
      // Sin headers manuales: el interceptor global de `dio` (ver
      // injection_container.dart) ya agrega Authorization + x-tenant-id
      // a cualquier ruta que no sea de /auth/*.
      final response = await dio.patch(
        ApiConstants.userProfile,
        data: {
          if (firstName != null) 'firstName': firstName,
          if (lastName != null) 'lastName': lastName,
          if (phoneNumber != null) 'phoneNumber': phoneNumber,
        },
      );

      if (response.statusCode != 200) {
        throw ServerException('Failed to update profile', response.statusCode);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw UnauthorizedException('Session expired');
      } else if (e.response?.statusCode == 400) {
        throw ValidationException(
          ApiResponseUtils.errorMessage(e) ?? 'Datos inválidos',
        );
      } else if (e.type == DioExceptionType.unknown) {
        throw NetworkException('No internet connection');
      } else {
        throw ServerException(
          ApiResponseUtils.errorMessage(e) ?? 'Server error',
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
