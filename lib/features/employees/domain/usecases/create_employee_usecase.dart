import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/employee.dart';
import '../repositories/employee_repository.dart';

/// Crea un nuevo empleado.
class CreateEmployeeUseCase {
  final EmployeeRepository repository;

  CreateEmployeeUseCase(this.repository);

  Future<Either<Failure, Employee>> call({
    required String fullName,
    required String email,
    required String roleId,
    String? phone,
    String? password,
    String? employeeCode,
    EmployeeStatus? status,
  }) {
    return repository.createEmployee(
      fullName: fullName,
      email: email,
      roleId: roleId,
      phone: phone,
      password: password,
      employeeCode: employeeCode,
      status: status,
    );
  }
}
