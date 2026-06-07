import 'package:get/get.dart';
import '../../domain/entities/modifier.dart';
import '../../domain/usecases/get_modifiers_usecase.dart';
import '../../domain/usecases/delete_modifier_usecase.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Modifiers Controller
/// Gestiona el estado de la lista de modificadores
class ModifiersController extends GetxController {
  final GetModifiersUseCase getModifiersUseCase;
  final DeleteModifierUseCase deleteModifierUseCase;

  ModifiersController({
    required this.getModifiersUseCase,
    required this.deleteModifierUseCase,
  });

  // Observable state
  final RxList<Modifier> modifiers = <Modifier>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // Filters
  final RxString searchQuery = ''.obs;
  final Rx<String?> selectedProductId = Rx<String?>(null);
  final Rx<String?> selectedCategoryId = Rx<String?>(null);
  final RxBool showOnlyAvailable = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadModifiers();
  }

  /// Load modifiers from repository
  Future<void> loadModifiers() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final result = await getModifiersUseCase(
        productId: selectedProductId.value,
        categoryId: selectedCategoryId.value,
        isAvailable: showOnlyAvailable.value ? true : null,
      );

      result.fold(
        (failure) {
          errorMessage.value = _mapFailureToMessage(failure);
          modifiers.clear();
        },
        (modifiersList) {
          modifiers.value = modifiersList;

          // Apply search filter if exists
          if (searchQuery.value.isNotEmpty) {
            _applySearchFilter();
          }
        },
      );
    } catch (e) {
      errorMessage.value = 'Error inesperado: ${e.toString()}';
      modifiers.clear();
    } finally {
      isLoading.value = false;
    }
  }

  /// Refresh modifiers (pull to refresh)
  Future<void> refreshModifiers() async {
    await loadModifiers();
  }

  /// Search modifiers by name
  void searchModifiers(String query) {
    searchQuery.value = query;
    _applySearchFilter();
  }

  /// Apply search filter to current modifiers
  void _applySearchFilter() {
    if (searchQuery.value.isEmpty) {
      loadModifiers();
      return;
    }

    final query = searchQuery.value.toLowerCase();
    modifiers.value = modifiers.where((modifier) {
      return modifier.name.toLowerCase().contains(query) ||
          (modifier.description?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  /// Filter by product
  void filterByProduct(String? productId) {
    selectedProductId.value = productId;
    selectedCategoryId.value = null; // Clear category filter
    loadModifiers();
  }

  /// Filter by category
  void filterByCategory(String? categoryId) {
    selectedCategoryId.value = categoryId;
    selectedProductId.value = null; // Clear product filter
    loadModifiers();
  }

  /// Toggle available filter
  void toggleAvailableFilter() {
    showOnlyAvailable.value = !showOnlyAvailable.value;
    loadModifiers();
  }

  /// Clear all filters
  void clearFilters() {
    searchQuery.value = '';
    selectedProductId.value = null;
    selectedCategoryId.value = null;
    showOnlyAvailable.value = false;
    loadModifiers();
  }

  /// Delete a modifier
  Future<bool> deleteModifier(String id) async {
    try {
      final result = await deleteModifierUseCase(id);

      return result.fold(
        (failure) {
          errorMessage.value = _mapFailureToMessage(failure);
          AppSnackbar.show(
            'Error',
            errorMessage.value,
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 3),
          );
          return false;
        },
        (_) {
          // Remove from list
          modifiers.removeWhere((modifier) => modifier.id == id);

          AppSnackbar.show(
            'Éxito',
            'Modificador eliminado correctamente',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 2),
          );
          return true;
        },
      );
    } catch (e) {
      errorMessage.value = 'Error inesperado: ${e.toString()}';
      AppSnackbar.show(
        'Error',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return false;
    }
  }

  /// Map failure to user-friendly message
  String _mapFailureToMessage(dynamic failure) {
    return failure.toString().contains('NetworkFailure')
        ? 'Sin conexión a internet'
        : failure.toString().contains('ServerFailure')
            ? 'Error del servidor. Intenta más tarde'
            : failure.toString().contains('UnauthorizedFailure')
                ? 'No autorizado. Inicia sesión nuevamente'
                : 'Error al cargar modificadores';
  }

  /// Get modifier by ID from current list
  Modifier? getModifierById(String id) {
    try {
      return modifiers.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Check if has active filters
  bool get hasActiveFilters {
    return searchQuery.value.isNotEmpty ||
        selectedProductId.value != null ||
        selectedCategoryId.value != null ||
        showOnlyAvailable.value;
  }
}
