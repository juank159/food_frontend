import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/customer.dart';
import '../repositories/customer_repository.dart';

/// Update Customer Use Case
class UpdateCustomerUseCase {
  final CustomerRepository repository;

  UpdateCustomerUseCase(this.repository);

  Future<Either<Failure, Customer>> call({
    required String id,
    String? fullName,
    String? phone,
    String? email,
    String? notes,
    bool? isActive,
  }) async {
    return repository.updateCustomer(
      id: id,
      fullName: fullName,
      phone: phone,
      email: email,
      notes: notes,
      isActive: isActive,
    );
  }
}
