import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/create_employee_usecase.dart';
import '../../domain/usecases/get_employee_by_id_usecase.dart';
import '../../domain/usecases/get_employees_usecase.dart';
import '../../domain/usecases/update_employee_usecase.dart';
import '../controllers/employee_form_controller.dart';

/// Inyecta dependencias para el formulario de creación/edición.
class EmployeeFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<EmployeeFormController>(
      () => EmployeeFormController(
        createEmployeeUseCase: sl<CreateEmployeeUseCase>(),
        updateEmployeeUseCase: sl<UpdateEmployeeUseCase>(),
        getEmployeesUseCase: sl<GetEmployeesUseCase>(),
        getEmployeeByIdUseCase: sl<GetEmployeeByIdUseCase>(),
      ),
    );
  }
}
