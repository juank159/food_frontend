import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/get_order_by_id_usecase.dart';
import '../../domain/usecases/update_order_usecase.dart';
import '../controllers/edit_order_controller.dart';

class EditOrderBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<EditOrderController>(
      () => EditOrderController(
        getOrderByIdUseCase: sl<GetOrderByIdUseCase>(),
        updateOrderUseCase: sl<UpdateOrderUseCase>(),
      ),
    );
  }
}
