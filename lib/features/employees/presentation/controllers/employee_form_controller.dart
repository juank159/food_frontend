import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/employee_role.dart';
import '../../domain/usecases/create_employee_usecase.dart';
import '../../domain/usecases/get_employee_by_id_usecase.dart';
import '../../domain/usecases/get_employees_usecase.dart';
import '../../domain/usecases/update_employee_usecase.dart';
import 'employees_controller.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Controlador del formulario de creación/edición.
///
/// La lista de roles disponibles se infiere de los empleados ya cargados
/// (con `getEmployeesUseCase`) — el backend no expone aún un endpoint
/// `/roles` consumible desde este feature, así que reutilizamos los roles
/// que ya vienen embebidos en cada user.
class EmployeeFormController extends GetxController {
  final CreateEmployeeUseCase createEmployeeUseCase;
  final UpdateEmployeeUseCase updateEmployeeUseCase;
  final GetEmployeesUseCase getEmployeesUseCase;
  final GetEmployeeByIdUseCase getEmployeeByIdUseCase;

  EmployeeFormController({
    required this.createEmployeeUseCase,
    required this.updateEmployeeUseCase,
    required this.getEmployeesUseCase,
    required this.getEmployeeByIdUseCase,
  });

  // Estado del form
  final formKey = GlobalKey<FormState>();
  Employee? employeeToEdit;
  bool get isEditMode => employeeToEdit != null;

  // Loading flags
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxString errorMessage = ''.obs;

  // Text controllers
  late final TextEditingController firstNameController;
  late final TextEditingController lastNameController;
  late final TextEditingController emailController;
  late final TextEditingController phoneController;
  late final TextEditingController passwordController;
  late final TextEditingController employeeCodeController;

  // Estado reactivo
  final Rx<String?> selectedRoleId = Rx<String?>(null);
  final RxBool isActive = true.obs;
  final RxList<EmployeeRole> availableRoles = <EmployeeRole>[].obs;

  @override
  void onInit() {
    super.onInit();
    _initControllers();

    // Si hubo argumentos en la navegación los recogemos acá.
    final args = Get.arguments;
    if (args is Employee) {
      employeeToEdit = args;
      _hydrateFromEmployee(args);
    } else if (Get.parameters['id'] != null && employeeToEdit == null) {
      _loadFromId(Get.parameters['id']!);
    }

    _loadAvailableRoles();
  }

  @override
  void onClose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    employeeCodeController.dispose();
    super.onClose();
  }

  void _initControllers() {
    firstNameController = TextEditingController();
    lastNameController = TextEditingController();
    emailController = TextEditingController();
    phoneController = TextEditingController();
    passwordController = TextEditingController();
    employeeCodeController = TextEditingController();
  }

  void _hydrateFromEmployee(Employee emp) {
    firstNameController.text = emp.firstName;
    lastNameController.text = emp.lastName;
    emailController.text = emp.email;
    phoneController.text = emp.phone ?? '';
    employeeCodeController.text = emp.employeeCode ?? '';
    selectedRoleId.value = emp.roleId.isEmpty ? null : emp.roleId;
    isActive.value = emp.isActive;
  }

  Future<void> _loadFromId(String id) async {
    isLoading.value = true;
    final result = await getEmployeeByIdUseCase(id);
    result.fold(
      (failure) {
        errorMessage.value = failure.message;
      },
      (emp) {
        employeeToEdit = emp;
        _hydrateFromEmployee(emp);
      },
    );
    isLoading.value = false;
  }

  /// Carga todos los empleados sólo para extraer los roles únicos. Es la
  /// mejor aproximación hasta que exista un endpoint de roles dedicado.
  Future<void> _loadAvailableRoles() async {
    final result = await getEmployeesUseCase();
    result.fold(
      (_) {},
      (employees) {
        final seen = <String, EmployeeRole>{};
        for (final emp in employees) {
          final role = emp.role;
          if (role != null && role.id.isNotEmpty) {
            seen.putIfAbsent(role.id, () => role);
          }
        }
        availableRoles.value = seen.values.toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

        // Si en edición el rol del empleado no está en la lista (porque
        // ningún otro user lo usa), lo agregamos manualmente para que
        // aparezca seleccionado en el dropdown.
        if (isEditMode && employeeToEdit?.role != null) {
          final exists =
              availableRoles.any((r) => r.id == employeeToEdit!.role!.id);
          if (!exists) {
            availableRoles.insert(0, employeeToEdit!.role!);
          }
        }
      },
    );
  }

  // ─────────────────────── Validación ───────────────────────

  bool _validate() {
    errorMessage.value = '';
    if (!formKey.currentState!.validate()) {
      errorMessage.value = 'Por favor completá los campos requeridos';
      return false;
    }
    if (selectedRoleId.value == null || selectedRoleId.value!.isEmpty) {
      errorMessage.value = 'Seleccioná un rol para el empleado';
      return false;
    }
    return true;
  }

  // ─────────────────────── Save ───────────────────────

  Future<void> saveEmployee() async {
    if (!_validate()) {
      _toastError(errorMessage.value);
      return;
    }
    isSaving.value = true;
    try {
      if (isEditMode) {
        await _update();
      } else {
        await _create();
      }
    } finally {
      isSaving.value = false;
    }
  }

  String get _composedFullName {
    final first = firstNameController.text.trim();
    final last = lastNameController.text.trim();
    if (last.isEmpty) return first;
    return '$first $last';
  }

  EmployeeStatus get _statusFromSwitch {
    if (isEditMode) {
      // Si en edición se desmarca el switch y antes estaba suspendido,
      // mantenemos `suspended` para no pisar la decisión de quien suspendió.
      if (!isActive.value && employeeToEdit?.status == EmployeeStatus.suspended) {
        return EmployeeStatus.suspended;
      }
      return isActive.value ? EmployeeStatus.active : EmployeeStatus.inactive;
    }
    return isActive.value ? EmployeeStatus.active : EmployeeStatus.inactive;
  }

  Future<void> _create() async {
    final result = await createEmployeeUseCase(
      fullName: _composedFullName,
      email: emailController.text.trim(),
      roleId: selectedRoleId.value!,
      phone: phoneController.text.trim().isEmpty
          ? null
          : phoneController.text.trim(),
      password: passwordController.text.trim().isEmpty
          ? null
          : passwordController.text.trim(),
      employeeCode: employeeCodeController.text.trim().isEmpty
          ? null
          : employeeCodeController.text.trim(),
      status: _statusFromSwitch,
    );

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        _toastError(failure.message);
      },
      (employee) {
        _toastSuccess('Empleado creado');
        _refreshList();
        Get.back(result: employee);
      },
    );
  }

  Future<void> _update() async {
    final result = await updateEmployeeUseCase(
      id: employeeToEdit!.id,
      fullName: _composedFullName,
      email: emailController.text.trim(),
      phone: phoneController.text.trim().isEmpty
          ? null
          : phoneController.text.trim(),
      roleId: selectedRoleId.value,
      employeeCode: employeeCodeController.text.trim().isEmpty
          ? null
          : employeeCodeController.text.trim(),
      status: _statusFromSwitch,
    );

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        _toastError(failure.message);
      },
      (employee) {
        _toastSuccess('Empleado actualizado');
        _refreshList();
        Get.back(result: employee);
      },
    );
  }

  // ─────────────────────── Helpers ───────────────────────

  void _refreshList() {
    try {
      Get.find<EmployeesController>().refreshEmployees();
    } catch (_) {
      // No está montado — no es un error.
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
