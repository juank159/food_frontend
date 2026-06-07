import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../../orders/domain/usecases/get_orders_usecase.dart';
import '../../domain/repositories/customer_repository.dart';
import '../../domain/usecases/get_customer_by_id_usecase.dart';
import '../controllers/customer_detail_controller.dart';

/// Customer Detail Binding
///
/// Inyecta el `CustomerDetailController` con las dependencias que necesita
/// para cargar el cliente, sus addresses y sus últimas órdenes.
class CustomerDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CustomerDetailController>(
      () => CustomerDetailController(
        getCustomerByIdUseCase: sl<GetCustomerByIdUseCase>(),
        getOrdersUseCase: sl<GetOrdersUseCase>(),
        customerRepository: sl<CustomerRepository>(),
      ),
    );
  }
}
