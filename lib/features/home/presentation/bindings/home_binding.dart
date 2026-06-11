import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../../categories/domain/usecases/get_active_categories_usecase.dart';
import '../../../categories/domain/usecases/get_categories_usecase.dart';
import '../../../categories/domain/usecases/get_category_by_id_usecase.dart';
import '../../../categories/domain/usecases/get_category_tree_usecase.dart';
import '../../../categories/presentation/controllers/categories_controller.dart';
import '../../../products/domain/usecases/delete_modifier_usecase.dart';
import '../../../products/domain/usecases/get_available_products_usecase.dart';
import '../../../products/domain/usecases/get_modifiers_usecase.dart';
import '../../../products/domain/usecases/get_product_by_id_usecase.dart';
import '../../../products/domain/usecases/get_products_usecase.dart';
import '../../../orders/domain/usecases/create_order_usecase.dart';
import '../../../orders/domain/usecases/get_active_orders_usecase.dart';
import '../../../orders/domain/usecases/get_order_by_id_usecase.dart';
import '../../../orders/domain/usecases/get_orders_usecase.dart';
import '../../../orders/domain/usecases/update_order_status_usecase.dart';
import '../../../orders/presentation/controllers/orders_controller.dart';
import '../../../products/presentation/controllers/modifiers_controller.dart';
import '../../../products/presentation/controllers/products_controller.dart';
import '../../../tables/presentation/bindings/floor_plans_list_binding.dart';
import '../controllers/home_controller.dart';

/// Home Binding
///
/// Configura las dependencias para el módulo Home
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    // Home Controller
    Get.lazyPut<HomeController>(
      () => HomeController(),
    );

    // Products Controller - necesario porque ProductsPage está en el tab
    Get.lazyPut<ProductsController>(
      () => ProductsController(
        getProductsUseCase: sl<GetProductsUseCase>(),
        getProductByIdUseCase: sl<GetProductByIdUseCase>(),
        getAvailableProductsUseCase: sl<GetAvailableProductsUseCase>(),
      ),
    );

    // Categories Controller - necesario porque CategoriesPage está dentro de ProductsPage tabs
    Get.lazyPut<CategoriesController>(
      () => CategoriesController(
        getCategoriesUseCase: sl<GetCategoriesUseCase>(),
        getCategoryTreeUseCase: sl<GetCategoryTreeUseCase>(),
        getActiveCategoriesUseCase: sl<GetActiveCategoriesUseCase>(),
        getCategoryByIdUseCase: sl<GetCategoryByIdUseCase>(),
      ),
    );

    // Modifiers Controller - necesario porque ModifiersPage está dentro de ProductsPage tabs
    Get.lazyPut<ModifiersController>(
      () => ModifiersController(
        getModifiersUseCase: sl<GetModifiersUseCase>(),
        deleteModifierUseCase: sl<DeleteModifierUseCase>(),
      ),
    );

    // Orders Controller — el tab "Órdenes" del HomeScreen monta OrdersPage
    // directo (sin pantalla intermedia), así que necesita las dependencias
    // listas desde el inicio del Home, igual que Products/Categories.
    Get.lazyPut<OrdersController>(
      () => OrdersController(
        getOrdersUseCase: sl<GetOrdersUseCase>(),
        getOrderByIdUseCase: sl<GetOrderByIdUseCase>(),
        getActiveOrdersUseCase: sl<GetActiveOrdersUseCase>(),
        createOrderUseCase: sl<CreateOrderUseCase>(),
        updateOrderStatusUseCase: sl<UpdateOrderStatusUseCase>(),
      ),
    );

    // Floor plans list — para los roles waiter/cashier el tab "Mesas"
    // muestra `FloorPlansListPage` en lugar del tab "Productos". El
    // binding registra el controller y sus dependencias (datasource +
    // repository) de forma idempotente.
    FloorPlansListBinding().dependencies();
  }
}
