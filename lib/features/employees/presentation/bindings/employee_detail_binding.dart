import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/activate_employee_usecase.dart';
import '../../domain/usecases/delete_employee_usecase.dart';
import '../../domain/usecases/get_employee_by_id_usecase.dart';
import '../../domain/usecases/suspend_employee_usecase.dart';
import '../controllers/employee_detail_controller.dart';

/// Inyecta dependencias para la pantalla de detalle de empleado.
class EmployeeDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<EmployeeDetailController>(
      () => EmployeeDetailController(
        getEmployeeByIdUseCase: sl<GetEmployeeByIdUseCase>(),
        suspendEmployeeUseCase: sl<SuspendEmployeeUseCase>(),
        activateEmployeeUseCase: sl<ActivateEmployeeUseCase>(),
        deleteEmployeeUseCase: sl<DeleteEmployeeUseCase>(),
      ),
    );
  }
}
