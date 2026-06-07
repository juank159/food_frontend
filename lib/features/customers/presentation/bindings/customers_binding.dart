import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/delete_customer_usecase.dart';
import '../../domain/usecases/get_customer_statistics_usecase.dart';
import '../../domain/usecases/get_customers_usecase.dart';
import '../controllers/customers_controller.dart';

/// Customers Binding
///
/// Inyecta `CustomersController` con sus use cases. Lazy para que el
/// controller sólo se cree al entrar a la ruta.
class CustomersBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CustomersController>(
      () => CustomersController(
        getCustomersUseCase: sl<GetCustomersUseCase>(),
        getStatisticsUseCase: sl<GetCustomerStatisticsUseCase>(),
        deleteCustomerUseCase: sl<DeleteCustomerUseCase>(),
      ),
    );
  }
}
