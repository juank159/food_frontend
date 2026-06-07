import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/employee.dart';
import '../repositories/employee_repository.dart';

/// Reactiva un empleado previamente suspendido o inactivo.
class ActivateEmployeeUseCase {
  final EmployeeRepository repository;

  ActivateEmployeeUseCase(this.repository);

  Future<Either<Failure, Employee>> call(String id) {
    return repository.activateEmployee(id);
  }
}
