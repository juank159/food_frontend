import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../../categories/presentation/controllers/categories_controller.dart';
import '../controllers/product_form_controller.dart';

/// Product Form Binding
/// Maneja las dependencias del formulario de productos
class ProductFormBinding extends Bindings {
  @override
  void dependencies() {
    // Aseguramos que CategoriesController esté disponible
    if (!Get.isRegistered<CategoriesController>()) {
      Get.lazyPut<CategoriesController>(
        () => CategoriesController(
          getCategoriesUseCase: sl(),
          getCategoryTreeUseCase: sl(),
          getActiveCategoriesUseCase: sl(),
          getCategoryByIdUseCase: sl(),
        ),
      );
    }

    Get.lazyPut<ProductFormController>(
      () => ProductFormController(
        createProductUseCase: sl(),
        updateProductUseCase: sl(),
        createVariantUseCase: sl(),
        updateVariantUseCase: sl(),
        deleteVariantUseCase: sl(),
        createModifierGroupUseCase: sl(),
        updateModifierGroupUseCase: sl(),
        deleteModifierGroupUseCase: sl(),
        addModifiersToGroupUseCase: sl(),
        removeModifierFromGroupUseCase: sl(),
        getModifiersUseCase: sl(),
      ),
    );
  }
}
