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

      final result = await getProductsUseCase(
        categoryId: categoryId ?? selectedCategoryId.value,
        isAvailable: isAvailable ?? (showOnlyAvailable.value ? true : null),
        search:
            search ?? (searchQuery.value.isNotEmpty ? searchQuery.value : null),
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

  /// Buscar productos
  void searchProducts(String query) {
    searchQuery.value = query;
    loadProducts(search: query);
  }

  /// Filtrar por categoría
  void filterByCategory(String? categoryId) {
    selectedCategoryId.value = categoryId;
    loadProducts(categoryId: categoryId);
  }

  /// Toggle filtro de disponibles
  void toggleAvailableFilter() {
    showOnlyAvailable.value = !showOnlyAvailable.value;
    loadProducts(isAvailable: showOnlyAvailable.value ? true : null);
  }

  /// Limpiar filtros
  void clearFilters() {
    searchQuery.value = '';
    selectedCategoryId.value = null;
    showOnlyAvailable.value = false;
    loadProducts();
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
