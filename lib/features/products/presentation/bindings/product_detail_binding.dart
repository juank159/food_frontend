import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/get_product_by_id_usecase.dart';
import '../controllers/product_detail_controller.dart';

class ProductDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProductDetailController>(
      () => ProductDetailController(
        getProductByIdUseCase: sl<GetProductByIdUseCase>(),
      ),
    );
  }
}
