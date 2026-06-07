import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/employee.dart';

/// Contrato del repositorio de empleados.
///
/// Refleja 1:1 los endpoints expuestos por `users.controller.ts` del backend
/// — listar, filtrar por rol/estado, suspender / activar / eliminar — pero
/// presentándolos con el lenguaje del feature (Employee).
abstract class EmployeeRepository {
  /// Lista todos los empleados, con filtros opcionales por estado, rol y
  /// búsqueda libre.
  Future<Either<Failure, List<Employee>>> getEmployees({
    EmployeeStatus? status,
    String? roleId,
    String? search,
  });

  /// Sólo empleados activos — atajo del endpoint `/users/active`.
  Future<Either<Failure, List<Employee>>> getActiveEmployees();

  /// Detalle de un empleado por ID.
  Future<Either<Failure, Employee>> getEmployeeById(String id);

  /// Crea un nuevo empleado. `password` es opcional porque el endpoint
  /// actual no lo requiere — se incluye sólo si el form lo provee.
  Future<Either<Failure, Employee>> createEmployee({
    required String fullName,
    required String email,
    required String roleId,
    String? phone,
    String? password,
    String? employeeCode,
    EmployeeStatus? status,
  });

  /// Actualiza datos de un empleado.
  Future<Either<Failure, Employee>> updateEmployee({
    required String id,
    String? fullName,
    String? email,
    String? phone,
    String? roleId,
    String? employeeCode,
    EmployeeStatus? status,
  });

  /// Suspende un empleado (`PATCH /users/:id/suspend`).
  Future<Either<Failure, Employee>> suspendEmployee(String id);

  /// Reactiva un empleado (`PATCH /users/:id/activate`).
  Future<Either<Failure, Employee>> activateEmployee(String id);

  /// Elimina un empleado.
  Future<Either<Failure, void>> deleteEmployee(String id);
}
