import '../entities/employee.dart';
import '../repositories/employee_repository.dart';

/// Lista de empleados cacheada al instante, sin tocar la red — ver
/// `GetCachedProductsPeekUseCase` (mismo patrón, mismo porqué).
class GetCachedEmployeesPeekUseCase {
  final EmployeeRepository repository;

  GetCachedEmployeesPeekUseCase(this.repository);

  Future<List<Employee>?> call() => repository.getCachedEmployeesPeek();
}
