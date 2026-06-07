import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/get_customer_report_usecase.dart';
import '../controllers/customer_report_controller.dart';

/// Customer Report Binding
class CustomerReportBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CustomerReportController>(
      () => CustomerReportController(
        getCustomerReportUseCase: sl<GetCustomerReportUseCase>(),
      ),
    );
  }
}
