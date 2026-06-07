import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/customer.dart';
import '../repositories/customer_repository.dart';

/// Get Customers Use Case
/// Obtiene todos los clientes con filtros opcionales.
class GetCustomersUseCase {
  final CustomerRepository repository;

  GetCustomersUseCase(this.repository);

  Future<Either<Failure, List<Customer>>> call({
    bool? isActive,
    String? search,
  }) async {
    return repository.getCustomers(isActive: isActive, search: search);
  }
}
