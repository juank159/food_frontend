import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../../orders/domain/usecases/get_orders_usecase.dart';
import '../../domain/usecases/get_sales_report_usecase.dart';
import '../controllers/sales_report_controller.dart';

/// Sales Report Binding
///
/// Inyecta el `SalesReportController` resolviendo el usecase propio del
/// módulo (sales report) y el de órdenes (reusado para listar las
/// órdenes del rango).
class SalesReportBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SalesReportController>(
      () => SalesReportController(
        getSalesReportUseCase: sl<GetSalesReportUseCase>(),
        getOrdersUseCase: sl<GetOrdersUseCase>(),
      ),
    );
  }
}
