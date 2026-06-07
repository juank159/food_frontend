import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../../products/domain/usecases/get_products_usecase.dart';
import '../../domain/usecases/get_category_by_id_usecase.dart';
import '../controllers/category_detail_controller.dart';

/// Category Detail Binding
/// Inyecta dependencias para la pantalla de detalle de categoría.
class CategoryDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CategoryDetailController>(
      () => CategoryDetailController(
        getCategoryByIdUseCase: sl<GetCategoryByIdUseCase>(),
        getProductsUseCase: sl<GetProductsUseCase>(),
      ),
    );
  }
}
