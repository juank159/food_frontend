import '../entities/customer.dart';
import '../repositories/customer_repository.dart';

/// Lista de clientes cacheada al instante, sin tocar la red — ver
/// `GetCachedProductsPeekUseCase` (mismo patrón, mismo porqué).
class GetCachedCustomersPeekUseCase {
  final CustomerRepository repository;

  GetCachedCustomersPeekUseCase(this.repository);

  Future<List<Customer>?> call() => repository.getCachedCustomersPeek();
}
