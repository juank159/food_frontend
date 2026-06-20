import 'package:get/get.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/get_available_products_usecase.dart';
import '../../domain/usecases/get_product_by_id_usecase.dart';
import '../../domain/usecases/get_products_usecase.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Products Controller
/// Maneja el estado y lógica de la pantalla de productos
class ProductsController extends GetxController {
  final GetProductsUseCase getProductsUseCase;
  final GetProductByIdUseCase getProductByIdUseCase;
  final GetAvailableProductsUseCase getAvailableProductsUseCase;

  ProductsController({
    required this.getProductsUseCase,
    required this.getProductByIdUseCase,
    required this.getAvailableProductsUseCase,
  });

  // Observable states
  final RxList<Product> products = <Product>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final Rx<Product?> selectedProduct = Rx<Product?>(null);

  // Filtros
  final RxString searchQuery = ''.obs;
  final Rx<String?> selectedCategoryId = Rx<String?>(null);
  final RxBool showOnlyAvailable = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadProducts();
  }

  /// Cargar productos con filtros
  Future<void> loadProducts({
    String? categoryId,
    bool? isAvailable,
    String? search,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Cargamos el catálogo COMPLETO una sola vez y filtramos en memoria
      // (categoría, disponibilidad y texto) vía `filteredProducts`. Así
      // tocar un chip de categoría o tipear es INSTANTÁNEO y sin requests
      // — clave para la agilidad del POS y para no pegar contra el 429.
      // Solo se pasan filtros al backend si un caller los pide explícito.
      final result = await getProductsUseCase(
        categoryId: categoryId,
        isAvailable: isAvailable,
        search: search,
      );

      result.fold(
        (failure) {
          errorMessage.value = failure.message;
          AppSnackbar.show(
            'Error',
            failure.message,
            snackPosition: SnackPosition.TOP,
          );
        },
        (productsList) {
          products.value = productsList;
        },
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Cargar solo productos disponibles
  Future<void> loadAvailableProducts() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final result = await getAvailableProductsUseCase();

      result.fold(
        (failure) {
          errorMessage.value = failure.message;
          AppSnackbar.show(
            'Error',
            failure.message,
            snackPosition: SnackPosition.TOP,
          );
        },
        (productsList) {
          products.value = productsList;
        },
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Cargar detalles de un producto
  Future<void> loadProductDetails(String productId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final result = await getProductByIdUseCase(productId);

      result.fold(
        (failure) {
          errorMessage.value = failure.message;
          AppSnackbar.show(
            'Error',
            failure.message,
            snackPosition: SnackPosition.TOP,
          );
        },
        (product) {
          selectedProduct.value = product;
        },
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Buscar productos — CLIENT-SIDE.
  ///
  /// Antes esto llamaba `loadProducts(search:)` en CADA tecla, lo que
  /// disparaba una request al backend por carácter y pegaba contra el
  /// rate-limit (429 "Too Many Requests"), bloqueando el buscador. El
  /// catálogo de un POS es acotado, así que filtramos en memoria sobre
  /// `products` ya cargado: instantáneo y sin requests. La UI lee
  /// `filteredProducts`.
  void searchProducts(String query) {
    searchQuery.value = query;
  }

  /// Productos visibles aplicando TODOS los filtros client-side sobre la
  /// lista ya cargada: categoría, disponibilidad y texto (nombre /
  /// descripción / SKU). Reactivo: leerlo dentro de un `Obx` repinta al
  /// instante al tocar un chip o tipear, sin tocar el backend.
  List<Product> get filteredProducts {
    Iterable<Product> result = products;

    final cat = selectedCategoryId.value;
    if (cat != null) {
      result = result.where((p) => p.categoryId == cat);
    }

    if (showOnlyAvailable.value) {
      result = result.where((p) => p.isAvailable);
    }

    final q = searchQuery.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.description.toLowerCase().contains(q) ||
            (p.sku?.toLowerCase().contains(q) ?? false) ||
            (p.barcode?.toLowerCase().contains(q) ?? false);
      });
    }

    return result.toList();
  }

  /// Filtrar por categoría — client-side, instantáneo (solo setea el id;
  /// `filteredProducts` lo aplica). Sin request al backend.
  void filterByCategory(String? categoryId) {
    selectedCategoryId.value = categoryId;
  }

  /// Toggle filtro de disponibles — client-side, instantáneo.
  void toggleAvailableFilter() {
    showOnlyAvailable.value = !showOnlyAvailable.value;
  }

  /// Limpiar filtros — client-side, instantáneo (no recarga).
  void clearFilters() {
    searchQuery.value = '';
    selectedCategoryId.value = null;
    showOnlyAvailable.value = false;
  }

  /// Refrescar productos
  Future<void> refreshProducts() async {
    await loadProducts();
  }

  /// Inserta un producto al inicio de la lista local sin refetch.
  /// Útil tras crear desde el form para que el operario vea el nuevo
  /// producto al instante. Si ya existe un producto con el mismo id
  /// (caso edge: doble submit), lo reemplaza in-place.
  void addOrReplaceProduct(Product product) {
    final existingIndex = products.indexWhere((p) => p.id == product.id);
    if (existingIndex >= 0) {
      products[existingIndex] = product;
    } else {
      products.insert(0, product);
    }
  }
}
