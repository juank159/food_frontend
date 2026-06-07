import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/auth_response.dart';
import '../repositories/auth_repository.dart';

/// Login Use Case
/// Single responsibility: Handle login business logic
class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  Future<Either<Failure, AuthResponse>> call({
    required String email,
    required String password,
    required String tenantSubdomain,
  }) async {
    return await repository.login(
      email: email,
      password: password,
      tenantSubdomain: tenantSubdomain,
    );
  }
}
