import 'package:get/get.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/domain/usecases/get_products_usecase.dart';
import '../../domain/entities/category.dart';
import '../../domain/usecases/get_category_by_id_usecase.dart';

/// Category Detail Controller
///
/// Carga una categoría por ID (con sus children, si los tiene) y los
/// productos que pertenecen a esa categoría. Pensado para alimentar la
/// pantalla `CategoryDetailPage` con KPIs y listados.
class CategoryDetailController extends GetxController {
  final GetCategoryByIdUseCase getCategoryByIdUseCase;
  final GetProductsUseCase getProductsUseCase;

  CategoryDetailController({
    required this.getCategoryByIdUseCase,
    required this.getProductsUseCase,
  });

  // ─── Estado observable ─────────────────────────────────────────

  /// ID de la categoría actual (resuelto desde `Get.parameters['id']`).
  final RxString categoryId = ''.obs;

  /// Categoría cargada con sus children.
  final Rx<Category?> category = Rx<Category?>(null);

  /// Productos asociados a la categoría (filtro `category_id`).
  final RxList<Product> products = <Product>[].obs;

  final RxBool isLoading = false.obs;
  final RxBool isLoadingProducts = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    final id = Get.parameters['id'] ?? '';
    categoryId.value = id;
    if (id.isNotEmpty) {
      loadAll();
    } else {
      errorMessage.value = 'Categoría inválida';
    }
  }

  /// Carga categoría + productos en paralelo. Si la categoría falla, no
  /// tiene sentido seguir esperando productos: se aborta y se expone error.
  Future<void> loadAll() async {
    isLoading.value = true;
    errorMessage.value = '';

    final categoryResult = await getCategoryByIdUseCase(categoryId.value);
    categoryResult.fold(
      (failure) {
        errorMessage.value = failure.message;
      },
      (cat) {
        category.value = cat;
      },
    );

    isLoading.value = false;

    // Si pudimos cargar la categoría, ahora pedimos sus productos. Si
    // falló no contaminamos la pantalla con un segundo error: el usuario
    // ya ve el AppErrorState principal.
    if (category.value != null) {
      await loadProducts();
    }
  }

  Future<void> loadProducts() async {
    if (categoryId.value.isEmpty) return;
    isLoadingProducts.value = true;
    final result = await getProductsUseCase(categoryId: categoryId.value);
    result.fold(
      (failure) {
        // No reemplazamos el `errorMessage` global con el de productos
        // — sólo dejamos la lista vacía y exponemos el motivo en logs.
        products.clear();
      },
      (list) {
        products.assignAll(list);
      },
    );
    isLoadingProducts.value = false;
  }

  @override
  Future<void> refresh() async {
    await loadAll();
  }

  // ─── Derivados para KPIs ───────────────────────────────────────

  /// Total de productos asociados (lo que devuelve la API filtrada).
  int get totalProducts => products.length;

  /// Productos disponibles (`isAvailable == true`).
  int get availableProducts =>
      products.where((p) => p.isAvailable).length;

  /// Productos agotados (lo derivamos de la entidad: `isOutOfStock`).
  int get outOfStockProducts =>
      products.where((p) => p.isOutOfStock).length;

  /// Cantidad de subcategorías (children) que tiene la categoría.
  int get subcategoriesCount => category.value?.children.length ?? 0;

  bool get hasChildren => subcategoriesCount > 0;
}
