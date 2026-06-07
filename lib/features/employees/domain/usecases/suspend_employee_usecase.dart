import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/employee.dart';
import '../repositories/employee_repository.dart';

/// Suspende un empleado — el endpoint `/users/:id/suspend` deja la cuenta
/// en estado `suspended` sin borrarla.
class SuspendEmployeeUseCase {
  final EmployeeRepository repository;

  SuspendEmployeeUseCase(this.repository);

  Future<Either<Failure, Employee>> call(String id) {
    return repository.suspendEmployee(id);
  }
}
