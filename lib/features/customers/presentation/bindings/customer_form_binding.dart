import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/customer.dart';
import '../../domain/usecases/create_customer_usecase.dart';
import '../../domain/usecases/update_customer_usecase.dart';
import '../controllers/customer_form_controller.dart';

/// Customer Form Binding
///
/// Construye el controller del form. Si la ruta recibió un `Customer`
/// como argumento (`Get.arguments`), lo seteamos como `customerToEdit`
/// para que el form arranque en modo edición.
class CustomerFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CustomerFormController>(() {
      final controller = CustomerFormController(
        createCustomerUseCase: sl<CreateCustomerUseCase>(),
        updateCustomerUseCase: sl<UpdateCustomerUseCase>(),
      );
      final args = Get.arguments;
      if (args is Customer) {
        controller.customerToEdit = args;
      }
      return controller;
    });
  }
}
