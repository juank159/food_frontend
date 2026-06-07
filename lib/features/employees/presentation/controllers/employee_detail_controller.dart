import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../domain/entities/employee.dart';
import '../../domain/usecases/activate_employee_usecase.dart';
import '../../domain/usecases/delete_employee_usecase.dart';
import '../../domain/usecases/get_employee_by_id_usecase.dart';
import '../../domain/usecases/suspend_employee_usecase.dart';
import 'employees_controller.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Estado principal del detalle.
enum EmployeeDetailStatus { loading, loaded, error }

/// Controlador de la pantalla de detalle de empleado.
///
/// Carga el empleado y, en una segunda pasada, las "estadísticas". El
/// backend todavía no expone `GET /users/:id/statistics` como endpoint
/// dedicado, así que el controller mantiene los KPIs derivados del propio
/// `Employee` (`totalOrdersHandled`, `totalSalesAmount`, `lastLogin`,
/// `averageServiceRating`). Cuando el endpoint exista, se conecta acá
/// sin tocar la UI.
class EmployeeDetailController extends GetxController {
  final GetEmployeeByIdUseCase getEmployeeByIdUseCase;
  final SuspendEmployeeUseCase suspendEmployeeUseCase;
  final ActivateEmployeeUseCase activateEmployeeUseCase;
  final DeleteEmployeeUseCase deleteEmployeeUseCase;

  EmployeeDetailController({
    required this.getEmployeeByIdUseCase,
    required this.suspendEmployeeUseCase,
    required this.activateEmployeeUseCase,
    required this.deleteEmployeeUseCase,
  });

  // ─────────────────────────── Estado ───────────────────────────

  final Rx<EmployeeDetailStatus> status =
      EmployeeDetailStatus.loading.obs;
  final RxString errorMessage = ''.obs;
  final Rxn<Employee> employee = Rxn<Employee>();
  final RxBool isMutating = false.obs;

  String? employeeId;

  @override
  void onInit() {
    super.onInit();
    employeeId = Get.parameters['id'];
    if (employeeId == null || employeeId!.isEmpty) {
      status.value = EmployeeDetailStatus.error;
      errorMessage.value = 'No se pudo identificar el empleado';
      return;
    }
    loadEmployee();
  }

  // ─────────────────────────── Carga ───────────────────────────

  Future<void> loadEmployee() async {
    if (employeeId == null) return;
    status.value = EmployeeDetailStatus.loading;
    errorMessage.value = '';

    final result = await getEmployeeByIdUseCase(employeeId!);
    result.fold(
      (failure) {
        status.value = EmployeeDetailStatus.error;
        errorMessage.value = failure.message;
      },
      (loaded) {
        employee.value = loaded;
        status.value = EmployeeDetailStatus.loaded;
      },
    );
  }

  /// Reload completo — usado por el `RefreshIndicator` y por el botón de
  /// reintentar en estado de error. No usamos el nombre `refresh` para no
  /// chocar con el `refresh()` heredado de `GetxController`.
  Future<void> reload() => loadEmployee();

  // ─────────────────────────── Mutaciones ───────────────────────────

  Future<void> suspendEmployee() async {
    final emp = employee.value;
    if (emp == null) return;
    isMutating.value = true;
    final result = await suspendEmployeeUseCase(emp.id);
    isMutating.value = false;
    result.fold(
      (failure) => _toastError(failure.message),
      (updated) {
        employee.value = updated;
        _toastSuccess('Empleado suspendido');
        _refreshListIfRegistered();
      },
    );
  }

  Future<void> activateEmployee() async {
    final emp = employee.value;
    if (emp == null) return;
    isMutating.value = true;
    final result = await activateEmployeeUseCase(emp.id);
    isMutating.value = false;
    result.fold(
      (failure) => _toastError(failure.message),
      (updated) {
        employee.value = updated;
        _toastSuccess('Empleado reactivado');
        _refreshListIfRegistered();
      },
    );
  }

  /// Pide confirmación y elimina al empleado. Si tuvo éxito, vuelve a la
  /// pantalla anterior con `result = true` para que la lista refresque.
  Future<void> deleteEmployee() async {
    final emp = employee.value;
    if (emp == null) return;

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Eliminar empleado'),
        content: Text(
          '¿Seguro que querés eliminar a ${emp.fullName}? Esta acción no se puede deshacer.',
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

    isMutating.value = true;
    final result = await deleteEmployeeUseCase(emp.id);
    isMutating.value = false;
    result.fold(
      (failure) => _toastError(failure.message),
      (_) {
        _toastSuccess('Empleado eliminado');
        _refreshListIfRegistered();
        // Volvemos al listado señalizando éxito.
        Get.back<bool>(result: true);
      },
    );
  }

  // ─────────────────────────── Derivados ───────────────────────────

  bool get isLoading => status.value == EmployeeDetailStatus.loading;
  bool get hasError => status.value == EmployeeDetailStatus.error;
  bool get isLoaded => status.value == EmployeeDetailStatus.loaded;

  // ─────────────────────────── Helpers ───────────────────────────

  void _refreshListIfRegistered() {
    if (Get.isRegistered<EmployeesController>()) {
      Get.find<EmployeesController>().refreshEmployees();
    }
  }

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
