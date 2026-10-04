import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/auth_response.dart';
import '../repositories/auth_repository.dart';

/// Confirma el código de 6 dígitos de [SignUpBusinessUseCase] y arranca
/// sesión — último paso del alta de negocio.
class ConfirmSignupUseCase {
  final AuthRepository repository;

  ConfirmSignupUseCase(this.repository);

  Future<Either<Failure, AuthResponse>> call({
    required String email,
    required String code,
  }) async {
    return await repository.confirmSignup(email: email, code: code);
  }
}
