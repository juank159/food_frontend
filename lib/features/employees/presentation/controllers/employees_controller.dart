import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/employee_role.dart';
import '../../domain/usecases/activate_employee_usecase.dart';
import '../../domain/usecases/delete_employee_usecase.dart';
import '../../domain/usecases/get_active_employees_usecase.dart';
import '../../domain/usecases/get_employees_usecase.dart';
import '../../domain/usecases/suspend_employee_usecase.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Filtros disponibles para la lista. `all` muestra todos los estados,
/// `active`/`suspended` los respectivos filtros.
enum EmployeeStatusFilter { all, active, suspended }

/// Controlador principal de la lista de empleados.
class EmployeesController extends GetxController {
  final GetEmployeesUseCase getEmployeesUseCase;
  final GetActiveEmployeesUseCase getActiveEmployeesUseCase;
  final SuspendEmployeeUseCase suspendEmployeeUseCase;
  final ActivateEmployeeUseCase activateEmployeeUseCase;
  final DeleteEmployeeUseCase deleteEmployeeUseCase;

  EmployeesController({
    required this.getEmployeesUseCase,
    required this.getActiveEmployeesUseCase,
    required this.suspendEmployeeUseCase,
    required this.activateEmployeeUseCase,
    required this.deleteEmployeeUseCase,
  });

  // Estado observable
  final RxList<Employee> employees = <Employee>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // Filtros
  final Rx<EmployeeStatusFilter> statusFilter =
      EmployeeStatusFilter.all.obs;
  final RxString searchQuery = ''.obs;
  final Rx<String?> roleFilter = Rx<String?>(null);

  @override
  void onInit() {
    super.onInit();
    loadEmployees();
  }

  /// Carga la lista aplicando los filtros actuales del controlador.
  Future<void> loadEmployees() async {
    isLoading.value = true;
    errorMessage.value = '';

    EmployeeStatus? statusValue;
    switch (statusFilter.value) {
      case EmployeeStatusFilter.active:
        statusValue = EmployeeStatus.active;
        break;
      case EmployeeStatusFilter.suspended:
        statusValue = EmployeeStatus.suspended;
        break;
      case EmployeeStatusFilter.all:
        statusValue = null;
        break;
    }

    final result = await getEmployeesUseCase(
      status: statusValue,
      roleId: roleFilter.value,
      search: searchQuery.value.isEmpty ? null : searchQuery.value,
    );

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        isLoading.value = false;
      },
      (list) {
        employees.value = list;
        isLoading.value = false;
      },
    );
  }

  /// Mismo refresh que `loadEmployees`, expuesto con un nombre que
  /// describe la intención.
  Future<void> refreshEmployees() => loadEmployees();

  // ─────────────────────── Filtros ───────────────────────

  void setStatusFilter(EmployeeStatusFilter filter) {
    statusFilter.value = filter;
    loadEmployees();
  }

  void setRoleFilter(String? roleId) {
    roleFilter.value = roleId;
    loadEmployees();
  }

  void searchEmployees(String query) {
    searchQuery.value = query.trim();
    loadEmployees();
  }

  void clearFilters() {
    statusFilter.value = EmployeeStatusFilter.all;
    roleFilter.value = null;
    searchQuery.value = '';
    loadEmployees();
  }

  // ─────────────────────── Mutaciones ───────────────────────

  Future<void> suspendEmployee(Employee employee) async {
    final result = await suspendEmployeeUseCase(employee.id);
    result.fold(
      (failure) => _toastError(failure.message),
      (_) {
        _toastSuccess('Empleado suspendido');
        loadEmployees();
      },
    );
  }

  Future<void> activateEmployee(Employee employee) async {
    final result = await activateEmployeeUseCase(employee.id);
    result.fold(
      (failure) => _toastError(failure.message),
      (_) {
        _toastSuccess('Empleado reactivado');
        loadEmployees();
      },
    );
  }

  Future<void> deleteEmployee(Employee employee) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Eliminar empleado'),
        content: Text(
          '¿Seguro que querés eliminar a ${employee.fullName}? Esta acción '
          'no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Get.back(result: true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await deleteEmployeeUseCase(employee.id);
    result.fold(
      (failure) => _toastError(failure.message),
      (_) {
        _toastSuccess('Empleado eliminado');
        loadEmployees();
      },
    );
  }

  // ─────────────────────── Derivados ───────────────────────

  int get totalCount => employees.length;
  int get activeCount => employees.where((e) => e.isActive).length;
  int get suspendedCount => employees.where((e) => e.isSuspended).length;

  /// Devuelve los roles únicos presentes en la lista actual — los usamos
  /// como chips de filtro inline sin tener que traer `/roles` por separado.
  List<EmployeeRole> get availableRoles {
    final seen = <String, EmployeeRole>{};
    for (final emp in employees) {
      final role = emp.role;
      if (role != null && role.id.isNotEmpty) {
        seen.putIfAbsent(role.id, () => role);
      }
    }
    return seen.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Cantidad de roles distintos — alimenta un KPI del header.
  int get distinctRoleCount => availableRoles.length;

  // ─────────────────────── Helpers ───────────────────────

  void _toastSuccess(String message) {
    AppSnackbar.show(
      'Listo',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppColors.success,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  void _toastError(String message) {
    AppSnackbar.show(
      'Error',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppColors.error,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
  }
}
