import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/employee_repository.dart';

/// Elimina definitivamente un empleado.
class DeleteEmployeeUseCase {
  final EmployeeRepository repository;

  DeleteEmployeeUseCase(this.repository);

  Future<Either<Failure, void>> call(String id) {
    return repository.deleteEmployee(id);
  }
}
