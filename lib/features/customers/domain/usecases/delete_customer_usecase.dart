import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/customer_repository.dart';

/// Delete Customer Use Case
class DeleteCustomerUseCase {
  final CustomerRepository repository;

  DeleteCustomerUseCase(this.repository);

  Future<Either<Failure, void>> call(String id) async {
    return repository.deleteCustomer(id);
  }
}
