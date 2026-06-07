import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/employee.dart';
import '../repositories/employee_repository.dart';

/// Actualiza datos de un empleado.
class UpdateEmployeeUseCase {
  final EmployeeRepository repository;

  UpdateEmployeeUseCase(this.repository);

  Future<Either<Failure, Employee>> call({
    required String id,
    String? fullName,
    String? email,
    String? phone,
    String? roleId,
    String? employeeCode,
    EmployeeStatus? status,
  }) {
    return repository.updateEmployee(
      id: id,
      fullName: fullName,
      email: email,
      phone: phone,
      roleId: roleId,
      employeeCode: employeeCode,
      status: status,
    );
  }
}
