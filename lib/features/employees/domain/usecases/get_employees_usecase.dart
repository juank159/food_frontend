import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/employee.dart';
import '../repositories/employee_repository.dart';

/// Lista empleados con filtros opcionales.
class GetEmployeesUseCase {
  final EmployeeRepository repository;

  GetEmployeesUseCase(this.repository);

  Future<Either<Failure, List<Employee>>> call({
    EmployeeStatus? status,
    String? roleId,
    String? search,
  }) {
    return repository.getEmployees(
      status: status,
      roleId: roleId,
      search: search,
    );
  }
}
