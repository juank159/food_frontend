import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

/// Pide un código nuevo cuando el de [SignUpBusinessUseCase] ya venció
/// (10 min) — lo que toca el usuario cuando el timer de la pantalla
/// de confirmación llega a cero.
class ResendSignupCodeUseCase {
  final AuthRepository repository;

  ResendSignupCodeUseCase(this.repository);

  Future<Either<Failure, void>> call({required String email}) async {
    return await repository.resendSignupCode(email: email);
  }
}
