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

  /// Get current user
  Future<Either<Failure, User>> getCurrentUser();

  /// Refresh access token
  Future<Either<Failure, AuthResponse>> refreshToken();

  /// Logout
  Future<Either<Failure, void>> logout();

  /// Check if user is logged in
  Future<bool> isLoggedIn();

  /// Get stored access token
  Future<String?> getAccessToken();
}
