import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/get_product_sales_usecase.dart';
import '../controllers/product_sales_controller.dart';

class ProductSalesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProductSalesController>(
      () => ProductSalesController(
        getProductSalesUseCase: sl<GetProductSalesUseCase>(),
      ),
    );
  }
}
