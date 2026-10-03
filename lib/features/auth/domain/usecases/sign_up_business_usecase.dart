import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/auth_response.dart';
import '../repositories/auth_repository.dart';

/// Sign Up Business Use Case
///
/// Alta de un negocio NUEVO (tenant + dueño) en un solo paso — usado
/// por la pantalla "Crear mi restaurante". Distinto de [RegisterUseCase],
/// que suma un usuario a un tenant que YA existe.
class SignUpBusinessUseCase {
  final AuthRepository repository;

  SignUpBusinessUseCase(this.repository);

  Future<Either<Failure, AuthResponse>> call({
    required String businessName,
    required String businessType,
    required String subdomain,
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    return await repository.signUp(
      businessName: businessName,
      businessType: businessType,
      subdomain: subdomain,
      email: email,
      password: password,
      fullName: fullName,
      phoneNumber: phoneNumber,
    );
  }
}
