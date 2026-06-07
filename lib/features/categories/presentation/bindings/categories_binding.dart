import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/get_active_categories_usecase.dart';
import '../../domain/usecases/get_categories_usecase.dart';
import '../../domain/usecases/get_category_by_id_usecase.dart';
import '../../domain/usecases/get_category_tree_usecase.dart';
import '../controllers/categories_controller.dart';

/// Categories Binding
/// Inyecta dependencias para el módulo de categorías
class CategoriesBinding extends Bindings {
  @override
  void dependencies() {
    // Controller
    Get.lazyPut<CategoriesController>(
      () => CategoriesController(
        getCategoriesUseCase: sl<GetCategoriesUseCase>(),
        getCategoryTreeUseCase: sl<GetCategoryTreeUseCase>(),
        getActiveCategoriesUseCase: sl<GetActiveCategoriesUseCase>(),
        getCategoryByIdUseCase: sl<GetCategoryByIdUseCase>(),
      ),
    );
  }
}
