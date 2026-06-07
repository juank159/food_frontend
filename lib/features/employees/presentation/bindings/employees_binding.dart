import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/activate_employee_usecase.dart';
import '../../domain/usecases/delete_employee_usecase.dart';
import '../../domain/usecases/get_active_employees_usecase.dart';
import '../../domain/usecases/get_employees_usecase.dart';
import '../../domain/usecases/suspend_employee_usecase.dart';
import '../controllers/employees_controller.dart';

/// Inyecta dependencias para la lista de empleados.
class EmployeesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<EmployeesController>(
      () => EmployeesController(
        getEmployeesUseCase: sl<GetEmployeesUseCase>(),
        getActiveEmployeesUseCase: sl<GetActiveEmployeesUseCase>(),
        suspendEmployeeUseCase: sl<SuspendEmployeeUseCase>(),
        activateEmployeeUseCase: sl<ActivateEmployeeUseCase>(),
        deleteEmployeeUseCase: sl<DeleteEmployeeUseCase>(),
      ),
    );
  }
}
