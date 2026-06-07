import 'package:get/get.dart';
import '../../domain/entities/category.dart';
import '../../domain/usecases/get_active_categories_usecase.dart';
import '../../domain/usecases/get_categories_usecase.dart';
import '../../domain/usecases/get_category_by_id_usecase.dart';
import '../../domain/usecases/get_category_tree_usecase.dart';

/// Categories Controller
/// Controlador para gestionar el estado de las categorías
class CategoriesController extends GetxController {
  final GetCategoriesUseCase getCategoriesUseCase;
  final GetCategoryTreeUseCase getCategoryTreeUseCase;
  final GetActiveCategoriesUseCase getActiveCategoriesUseCase;
  final GetCategoryByIdUseCase getCategoryByIdUseCase;

  CategoriesController({
    required this.getCategoriesUseCase,
    required this.getCategoryTreeUseCase,
    required this.getActiveCategoriesUseCase,
    required this.getCategoryByIdUseCase,
  });

  // Observable states
  final RxList<Category> categories = <Category>[].obs;
  final RxList<Category> categoryTree = <Category>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final Rx<Category?> selectedCategory = Rx<Category?>(null);

  // Filter states
  final RxString searchQuery = ''.obs;
  final RxBool showOnlyActive = true.obs;
  final RxBool isTreeView = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadCategories();
  }

  /// Carga todas las categorías con filtros
  Future<void> loadCategories({bool? isActive, String? search}) async {
    isLoading.value = true;
    errorMessage.value = '';

    final result = await getCategoriesUseCase(
      isActive: isActive ?? (showOnlyActive.value ? true : null),
      search:
          search ?? (searchQuery.value.isNotEmpty ? searchQuery.value : null),
    );

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        isLoading.value = false;
      },
      (categoriesList) {
        categories.value = categoriesList;
        isLoading.value = false;
      },
    );
  }

  /// Carga el árbol de categorías
  Future<void> loadCategoryTree({bool? isActive}) async {
    isLoading.value = true;
    errorMessage.value = '';

    final result = await getCategoryTreeUseCase(
      isActive: isActive ?? (showOnlyActive.value ? true : null),
    );

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        isLoading.value = false;
      },
      (tree) {
        categoryTree.value = tree;
        isLoading.value = false;
      },
    );
  }

  /// Carga solo las categorías activas
  Future<void> loadActiveCategories() async {
    isLoading.value = true;
    errorMessage.value = '';

    final result = await getActiveCategoriesUseCase();

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        isLoading.value = false;
      },
      (categoriesList) {
        categories.value = categoriesList;
        isLoading.value = false;
      },
    );
  }

  /// Carga los detalles de una categoría
  Future<void> loadCategoryDetails(String categoryId) async {
    isLoading.value = true;
    errorMessage.value = '';

    final result = await getCategoryByIdUseCase(categoryId);

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        isLoading.value = false;
      },
      (category) {
        selectedCategory.value = category;
        isLoading.value = false;
      },
    );
  }

  /// Busca categorías por nombre
  Future<void> searchCategories(String query) async {
    searchQuery.value = query;
    await loadCategories(search: query);
  }

  /// Alterna el filtro de solo activos
  void toggleActiveFilter() {
    showOnlyActive.value = !showOnlyActive.value;
    if (isTreeView.value) {
      loadCategoryTree();
    } else {
      loadCategories();
    }
  }

  /// Alterna entre vista de lista y vista de árbol
  Future<void> toggleTreeView() async {
    isTreeView.value = !isTreeView.value;
    if (isTreeView.value) {
      await loadCategoryTree();
    } else {
      await loadCategories();
    }
  }

  /// Limpia todos los filtros
  void clearFilters() {
    searchQuery.value = '';
    showOnlyActive.value = true;
    loadCategories();
  }

  /// Refresca la lista de categorías
  Future<void> refreshCategories() async {
    if (isTreeView.value) {
      await loadCategoryTree();
    } else {
      await loadCategories();
    }
  }

  /// Limpia la categoría seleccionada
  void clearSelectedCategory() {
    selectedCategory.value = null;
  }

  /// Obtiene las categorías raíz del árbol
  List<Category> get rootCategories {
    if (isTreeView.value) {
      return categoryTree;
    }
    return categories.where((cat) => cat.isRootCategory).toList();
  }

  /// Obtiene el número total de categorías
  int get totalCategories {
    return isTreeView.value ? categoryTree.length : categories.length;
  }

  /// Verifica si hay categorías cargadas
  bool get hasCategories {
    return isTreeView.value ? categoryTree.isNotEmpty : categories.isNotEmpty;
  }
}
