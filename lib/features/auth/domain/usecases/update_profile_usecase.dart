import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Update Profile Use Case — actualiza nombre/apellido/teléfono del
/// usuario autenticado (`PATCH /users/me`). El email nunca se puede
/// cambiar desde acá (ver `ProfileScreen`).
class UpdateProfileUseCase {
  final AuthRepository repository;

  UpdateProfileUseCase(this.repository);

  Future<Either<Failure, User>> call({
    String? firstName,
    String? lastName,
    String? phoneNumber,
  }) async {
    return await repository.updateProfile(
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
    );
  }
}
