import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/employee.dart';
import '../repositories/employee_repository.dart';

/// Atajo al endpoint `/users/active` — lista sólo empleados habilitados.
class GetActiveEmployeesUseCase {
  final EmployeeRepository repository;

  GetActiveEmployeesUseCase(this.repository);

  Future<Either<Failure, List<Employee>>> call() {
    return repository.getActiveEmployees();
  }
}
