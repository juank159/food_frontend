import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/create_category_usecase.dart';
import '../../domain/usecases/update_category_usecase.dart';
import '../../domain/usecases/get_categories_usecase.dart';
import '../controllers/category_form_controller.dart';

/// Category Form Binding
/// Inicializa las dependencias del formulario de categorías
class CategoryFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CategoryFormController>(
      () => CategoryFormController(
        createCategoryUseCase: sl<CreateCategoryUseCase>(),
        updateCategoryUseCase: sl<UpdateCategoryUseCase>(),
        getCategoriesUseCase: sl<GetCategoriesUseCase>(),
      ),
    );
  }
}
