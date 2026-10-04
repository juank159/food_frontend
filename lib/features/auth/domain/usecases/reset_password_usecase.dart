import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

/// Confirma el código de 6 dígitos de [ForgotPasswordUseCase] y cambia
/// la contraseña.
class ResetPasswordUseCase {
  final AuthRepository repository;

  ResetPasswordUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    return await repository.resetPassword(
      email: email,
      code: code,
      newPassword: newPassword,
    );
  }
}
