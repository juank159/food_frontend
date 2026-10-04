import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/auth_response.dart';
import '../entities/user.dart';

/// Auth Repository Interface (Domain Layer)
/// Defines the contract for authentication operations
abstract class AuthRepository {
  /// Login with email and password against a specific tenant (subdomain).
  Future<Either<Failure, AuthResponse>> login({
    required String email,
    required String password,
    required String tenantSubdomain,
  });

  /// Register new user in the given tenant (subdomain).
  Future<Either<Failure, AuthResponse>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phoneNumber,
    required String tenantSubdomain,
  });

  /// Crea un negocio NUEVO (tenant + dueño) en un solo paso. Distinto
  /// de [register]: no requiere `tenantSubdomain` porque todavía no
  /// existe ningún tenant, es justo lo que crea. NO inicia sesión —
  /// manda un código de 6 dígitos; confirmarlo con [confirmSignup].
  Future<Either<Failure, void>> signUp({
    required String businessName,
    required String businessType,
    required String subdomain,
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  });

  /// Confirma el código de 6 dígitos de [signUp] y arranca sesión.
  Future<Either<Failure, AuthResponse>> confirmSignup({
    required String email,
    required String code,
  });

  /// Pide un código de recuperación de contraseña por email. Siempre
  /// "éxito" del lado del cliente — el backend nunca revela si el
  /// email existe o no (anti-enumeración).
  Future<Either<Failure, void>> forgotPassword({required String email});

  /// Confirma el código de 6 dígitos de [forgotPassword] y cambia la
  /// contraseña.
  Future<Either<Failure, void>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });

  /// Confirma un email con un código de 6 dígitos SIN arrancar sesión
  /// (a diferencia de [confirmSignup]).
  Future<Either<Failure, void>> verifyEmail({
    required String email,
    required String code,
  });

  /// Get current user
  Future<Either<Failure, User>> getCurrentUser();

  /// Actualiza el perfil del usuario autenticado (nombre, apellido,
  /// teléfono). Devuelve el `User` actualizado — el caller debe
  /// reemplazar el usuario en memoria (`AuthController.currentUser`)
  /// con este resultado.
  Future<Either<Failure, User>> updateProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
  });

  /// Refresh access token
  Future<Either<Failure, AuthResponse>> refreshToken();

  /// Logout
  Future<Either<Failure, void>> logout();

  /// Check if user is logged in
  Future<bool> isLoggedIn();

  /// Get stored access token
  Future<String?> getAccessToken();
}
