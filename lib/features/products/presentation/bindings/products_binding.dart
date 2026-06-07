import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../../categories/domain/usecases/get_active_categories_usecase.dart';
import '../../../categories/domain/usecases/get_categories_usecase.dart';
import '../../../categories/domain/usecases/get_category_by_id_usecase.dart';
import '../../../categories/domain/usecases/get_category_tree_usecase.dart';
import '../../../categories/presentation/controllers/categories_controller.dart';
import '../../domain/usecases/delete_modifier_usecase.dart';
import '../../domain/usecases/get_available_products_usecase.dart';
import '../../domain/usecases/get_modifiers_usecase.dart';
import '../../domain/usecases/get_product_by_id_usecase.dart';
import '../../domain/usecases/get_products_usecase.dart';
import '../controllers/modifiers_controller.dart';
import '../controllers/products_controller.dart';

/// Products Binding
/// Inyecta dependencias para el módulo de productos, categorías y modificadores
class ProductsBinding extends Bindings {
  @override
  void dependencies() {
    // Products Controller - usar put para que se inicialice inmediatamente
    Get.put<ProductsController>(
      ProductsController(
        getProductsUseCase: sl<GetProductsUseCase>(),
        getProductByIdUseCase: sl<GetProductByIdUseCase>(),
        getAvailableProductsUseCase: sl<GetAvailableProductsUseCase>(),
      ),
    );

    // Categories Controller - usar put para que esté disponible en el tab
    Get.put<CategoriesController>(
      CategoriesController(
        getCategoriesUseCase: sl<GetCategoriesUseCase>(),
        getCategoryTreeUseCase: sl<GetCategoryTreeUseCase>(),
        getActiveCategoriesUseCase: sl<GetActiveCategoriesUseCase>(),
        getCategoryByIdUseCase: sl<GetCategoryByIdUseCase>(),
      ),
    );

    // Modifiers Controller - usar put para que esté disponible en el tab
    Get.put<ModifiersController>(
      ModifiersController(
        getModifiersUseCase: sl<GetModifiersUseCase>(),
        deleteModifierUseCase: sl<DeleteModifierUseCase>(),
      ),
    );
  }
}
