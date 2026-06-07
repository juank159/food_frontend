import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/employee.dart';
import '../repositories/employee_repository.dart';

/// Detalle de un empleado por ID.
class GetEmployeeByIdUseCase {
  final EmployeeRepository repository;

  GetEmployeeByIdUseCase(this.repository);

  Future<Either<Failure, Employee>> call(String id) {
    return repository.getEmployeeById(id);
  }
}
