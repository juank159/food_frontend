import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/get_employee_report_usecase.dart';
import '../controllers/employee_report_controller.dart';

/// Employee Report Binding
class EmployeeReportBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<EmployeeReportController>(
      () => EmployeeReportController(
        getEmployeeReportUseCase: sl<GetEmployeeReportUseCase>(),
      ),
    );
  }
}
