import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/constants/modifier_enums.dart';
import '../../domain/entities/modifier.dart';
import '../../domain/usecases/create_modifier_usecase.dart';
import '../../domain/usecases/update_modifier_usecase.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/input_formatters.dart';
import 'modifiers_controller.dart';

/// Modifier Form Controller
/// Gestiona el estado del formulario de creación/edición de modificadores
class ModifierFormController extends GetxController {
  final CreateModifierUseCase createModifierUseCase;
  final UpdateModifierUseCase updateModifierUseCase;

  ModifierFormController({
    required this.createModifierUseCase,
    required this.updateModifierUseCase,
  });

  // Form key for validation
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // Text editing controllers
  late final TextEditingController nameController;
  late final TextEditingController descriptionController;
  late final TextEditingController priceController;
  late final TextEditingController maxQuantityController;
  late final TextEditingController sortOrderController;

  // Observable state
  final Rx<ModifierType> selectedType = ModifierType.addition.obs;
  final RxBool isAvailable = true.obs;
  final RxBool isSaving = false.obs;
  final RxString errorMessage = ''.obs;

  // Selected products and categories (applies_to)
  final RxList<String> selectedProductIds = <String>[].obs;
  final RxList<String> selectedCategoryIds = <String>[].obs;

  // Edit mode
  Modifier? _existingModifier;
  bool get isEditMode => _existingModifier != null;

  @override
  void onInit() {
    super.onInit();

    // Initialize text controllers
    nameController = TextEditingController();
    descriptionController = TextEditingController();
    priceController = TextEditingController(text: '0');
    maxQuantityController = TextEditingController();
    sortOrderController = TextEditingController(text: '0');

    // Load existing modifier if in edit mode
    final modifier = Get.arguments as Modifier?;
    if (modifier != null) {
      _loadModifierData(modifier);
    }
  }

  @override
  void onClose() {
    // Dispose controllers
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    maxQuantityController.dispose();
    sortOrderController.dispose();
    super.onClose();
  }

  /// Load existing modifier data for editing
  void _loadModifierData(Modifier modifier) {
    _existingModifier = modifier;

    nameController.text = modifier.name;
    descriptionController.text = modifier.description ?? '';
    // Formato es_CO con separadores de miles (mismo patrón que en
    // product_form y split_payment). `toStringAsFixed(2)` producía
    // "3000.00" que al pasar por el ThousandsSeparatorInputFormatter
    // se interpretaba mal al re-parsear.
    priceController.text =
        NumberFormatHelper.formatNumber(modifier.price.toInt());
    maxQuantityController.text = modifier.maxQuantity?.toString() ?? '';
    sortOrderController.text = modifier.sortOrder.toString();

    selectedType.value = modifier.type;
    isAvailable.value = modifier.isAvailable;

    // Hidratamos los IDs de `applies_to` (productos / categorías) cuando
    // el backend los entrega. Si la entidad no tiene la lista (null) se
    // deja la selección vacía.
    if (modifier.appliesToProducts != null) {
      selectedProductIds.assignAll(modifier.appliesToProducts!);
    }
    if (modifier.appliesToCategories != null) {
      selectedCategoryIds.assignAll(modifier.appliesToCategories!);
    }
  }

  /// Change modifier type
  void setModifierType(ModifierType type) {
    selectedType.value = type;
  }

  /// Toggle availability
  void toggleAvailability(bool value) {
    isAvailable.value = value;
  }

  /// Add product to applies_to
  void addProduct(String productId) {
    if (!selectedProductIds.contains(productId)) {
      selectedProductIds.add(productId);
    }
  }

  /// Remove product from applies_to
  void removeProduct(String productId) {
    selectedProductIds.remove(productId);
  }

  /// Add category to applies_to
  void addCategory(String categoryId) {
    if (!selectedCategoryIds.contains(categoryId)) {
      selectedCategoryIds.add(categoryId);
    }
  }

  /// Remove category from applies_to
  void removeCategory(String categoryId) {
    selectedCategoryIds.remove(categoryId);
  }

  /// Clear all applies_to selections
  void clearAppliesTo() {
    selectedProductIds.clear();
    selectedCategoryIds.clear();
  }

  /// Validate form
  bool _validateForm() {
    if (!formKey.currentState!.validate()) {
      return false;
    }

    // Validate price — parsea formato es_CO con separadores de miles.
    // El campo usa `ThousandsSeparatorInputFormatter` así que "1.500"
    // = 1500 (separador de miles), no 1.5.
    final priceInt = NumberFormatHelper.parseFormattedInt(priceController.text);
    final price = priceInt?.toDouble();
    if (price == null || price < 0) {
      errorMessage.value = 'El precio debe ser un número válido mayor o igual a 0';
      AppSnackbar.show(
        'Error de validación',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error.withValues(alpha: 0.1),
        colorText: Get.theme.colorScheme.error,
      );
      return false;
    }

    // Validate max quantity if provided
    if (maxQuantityController.text.isNotEmpty) {
      final maxQty = int.tryParse(maxQuantityController.text);
      if (maxQty == null || maxQty <= 0) {
        errorMessage.value = 'La cantidad máxima debe ser un número entero mayor a 0';
        AppSnackbar.show(
          'Error de validación',
          errorMessage.value,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.error.withValues(alpha: 0.1),
          colorText: Get.theme.colorScheme.error,
        );
        return false;
      }
    }

    return true;
  }

  /// Save modifier (create or update)
  Future<void> saveModifier() async {
    if (!_validateForm()) {
      return;
    }

    try {
      isSaving.value = true;
      errorMessage.value = '';

      // Parse values
      final name = nameController.text.trim();
      final description = descriptionController.text.trim().isNotEmpty
          ? descriptionController.text.trim()
          : null;
      final price =
          (NumberFormatHelper.parseFormattedInt(priceController.text) ?? 0)
              .toDouble();
      final maxQuantity = maxQuantityController.text.isNotEmpty
          ? int.parse(maxQuantityController.text)
          : null;
      final sortOrder = sortOrderController.text.isNotEmpty
          ? int.parse(sortOrderController.text)
          : null;

      // Prepare applies_to data
      final productIds = selectedProductIds.isNotEmpty ? selectedProductIds.toList() : null;
      final categoryIds = selectedCategoryIds.isNotEmpty ? selectedCategoryIds.toList() : null;

      if (isEditMode) {
        // Update existing modifier
        final result = await updateModifierUseCase(
          id: _existingModifier!.id,
          name: name,
          description: description,
          type: selectedType.value,
          price: price,
          maxQuantity: maxQuantity,
          isAvailable: isAvailable.value,
          sortOrder: sortOrder,
          productIds: productIds,
          categoryIds: categoryIds,
        );

        result.fold(
          (failure) {
            errorMessage.value = _mapFailureToMessage(failure);
            AppSnackbar.show(
              'Error',
              errorMessage.value,
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Get.theme.colorScheme.error.withValues(alpha: 0.1),
              colorText: Get.theme.colorScheme.error,
              duration: const Duration(seconds: 4),
            );
          },
          (modifier) {
            AppSnackbar.show(
              'Éxito',
              'Modificador actualizado correctamente',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Get.theme.colorScheme.primary.withValues(alpha: 0.1),
              colorText: Get.theme.colorScheme.primary,
              duration: const Duration(seconds: 2),
            );
            _refreshListIfRegistered();
            Get.back(result: modifier);
          },
        );
      } else {
        // Create new modifier
        final result = await createModifierUseCase(
          name: name,
          description: description,
          type: selectedType.value,
          price: price,
          maxQuantity: maxQuantity,
          isAvailable: isAvailable.value,
          sortOrder: sortOrder,
          productIds: productIds,
          categoryIds: categoryIds,
        );

        result.fold(
          (failure) {
            errorMessage.value = _mapFailureToMessage(failure);
            AppSnackbar.show(
              'Error',
              errorMessage.value,
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Get.theme.colorScheme.error.withValues(alpha: 0.1),
              colorText: Get.theme.colorScheme.error,
              duration: const Duration(seconds: 4),
            );
          },
          (modifier) {
            AppSnackbar.show(
              'Éxito',
              'Modificador creado correctamente',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Get.theme.colorScheme.primary.withValues(alpha: 0.1),
              colorText: Get.theme.colorScheme.primary,
              duration: const Duration(seconds: 2),
            );
            _refreshListIfRegistered();
            Get.back(result: modifier);
          },
        );
      }
    } catch (e) {
      errorMessage.value = 'Error inesperado: ${e.toString()}';
      AppSnackbar.show(
        'Error',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error.withValues(alpha: 0.1),
        colorText: Get.theme.colorScheme.error,
        duration: const Duration(seconds: 4),
      );
    } finally {
      isSaving.value = false;
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
                : failure.toString().contains('ValidationFailure')
                    ? 'Datos inválidos. Verifica el formulario'
                    : 'Error al guardar modificador';
  }

  /// Get type label in Spanish
  String getTypeLabel(ModifierType type) {
    switch (type) {
      case ModifierType.addition:
        return 'Agregar';
      case ModifierType.removal:
        return 'Quitar';
      case ModifierType.substitution:
        return 'Sustituir';
    }
  }

  /// Get type description
  String getTypeDescription(ModifierType type) {
    switch (type) {
      case ModifierType.addition:
        return 'Agregar un ingrediente o extra (ej: Extra queso)';
      case ModifierType.removal:
        return 'Quitar un ingrediente (ej: Sin cebolla)';
      case ModifierType.substitution:
        return 'Sustituir un ingrediente (ej: Pan integral)';
    }
  }

  /// Invalida la caché del `ModifiersController` si está vivo (la
  /// pantalla de listado). El `ProductFormController` no cachea
  /// modifiers (los va a buscar fresh cuando se abre el picker), así
  /// que no requiere invalidación.
  void _refreshListIfRegistered() {
    if (Get.isRegistered<ModifiersController>()) {
      Get.find<ModifiersController>().refreshModifiers();
    }
  }
}
