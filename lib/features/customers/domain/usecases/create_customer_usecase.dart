import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/customer.dart';
import '../repositories/customer_repository.dart';

/// Create Customer Use Case
class CreateCustomerUseCase {
  final CustomerRepository repository;

  CreateCustomerUseCase(this.repository);

  Future<Either<Failure, Customer>> call({
    required String fullName,
    required String phone,
    String? email,
    String? notes,
    bool isActive = true,
  }) async {
    return repository.createCustomer(
      fullName: fullName,
      phone: phone,
      email: email,
      notes: notes,
      isActive: isActive,
    );
  }
}
