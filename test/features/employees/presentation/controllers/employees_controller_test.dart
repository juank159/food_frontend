import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_plat/core/error/failures.dart';
import 'package:menu_plat/features/employees/domain/entities/employee.dart';
import 'package:menu_plat/features/employees/domain/repositories/employee_repository.dart';
import 'package:menu_plat/features/employees/domain/usecases/activate_employee_usecase.dart';
import 'package:menu_plat/features/employees/domain/usecases/delete_employee_usecase.dart';
import 'package:menu_plat/features/employees/domain/usecases/get_active_employees_usecase.dart';
import 'package:menu_plat/features/employees/domain/usecases/get_cached_employees_peek_usecase.dart';
import 'package:menu_plat/features/employees/domain/usecases/get_employees_usecase.dart';
import 'package:menu_plat/features/employees/domain/usecases/suspend_employee_usecase.dart';
import 'package:menu_plat/features/employees/presentation/controllers/employees_controller.dart';

Employee _employee(String id) => Employee(
      id: id,
      email: '$id@correo.com',
      fullName: 'Empleado $id',
      status: EmployeeStatus.active,
      roleId: 'role-1',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

class _UnusedRepo implements EmployeeRepository {
  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeGetEmployees implements GetEmployeesUseCase {
  Either<Failure, List<Employee>> result = Right(<Employee>[]);
  Duration delay = Duration.zero;

  @override
  EmployeeRepository get repository => _UnusedRepo();

  @override
  Future<Either<Failure, List<Employee>>> call({
    EmployeeStatus? status,
    String? roleId,
    String? search,
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return result;
  }
}

class _FakeGetCachedPeek implements GetCachedEmployeesPeekUseCase {
  List<Employee>? result;

  @override
  EmployeeRepository get repository => _UnusedRepo();

  @override
  Future<List<Employee>?> call() async => result;
}

void main() {
  late _FakeGetEmployees getEmployees;
  late _FakeGetCachedPeek getCachedPeek;
  late EmployeesController controller;

  setUp(() {
    getEmployees = _FakeGetEmployees();
    getCachedPeek = _FakeGetCachedPeek();
    controller = EmployeesController(
      getEmployeesUseCase: getEmployees,
      getActiveEmployeesUseCase: GetActiveEmployeesUseCase(_UnusedRepo()),
      suspendEmployeeUseCase: SuspendEmployeeUseCase(_UnusedRepo()),
      activateEmployeeUseCase: ActivateEmployeeUseCase(_UnusedRepo()),
      deleteEmployeeUseCase: DeleteEmployeeUseCase(_UnusedRepo()),
      getCachedEmployeesPeekUseCase: getCachedPeek,
    );
  });

  test(
    'local-first: pinta el caché de inmediato (sin filtros, default al abrir)',
    () async {
      getCachedPeek.result = [_employee('cached-1')];
      getEmployees.result = Right([_employee('fresh-1')]);
      getEmployees.delay = const Duration(milliseconds: 20);

      final future = controller.loadEmployees();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(controller.employees.map((e) => e.id), ['cached-1']);
      expect(controller.isLoading.value, isFalse);

      await future;
      expect(controller.employees.map((e) => e.id), ['fresh-1']);
    },
  );

  test('sin caché: muestra loading hasta que responda la red', () async {
    getCachedPeek.result = null;
    getEmployees.result = Right([_employee('fresh-1')]);

    await controller.loadEmployees();

    expect(controller.employees.map((e) => e.id), ['fresh-1']);
  });

  test(
    'con filtro de estado (ej. "Solo suspendidos"): no usa el peek',
    () async {
      getCachedPeek.result = [_employee('cached-1')];
      getEmployees.result = Right([_employee('suspendido-1')]);

      controller.statusFilter.value = EmployeeStatusFilter.suspended;
      await controller.loadEmployees();

      expect(controller.employees.map((e) => e.id), ['suspendido-1']);
    },
  );

  test(
    'si ya pintó del caché y la red falla, no borra lo pintado ni muestra error',
    () async {
      getCachedPeek.result = [_employee('cached-1')];
      getEmployees.result = const Left(NetworkFailure());

      await controller.loadEmployees();

      expect(controller.employees.map((e) => e.id), ['cached-1']);
      expect(controller.errorMessage.value, isEmpty);
    },
  );
}
