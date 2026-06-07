import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../domain/entities/category.dart';
import '../../domain/usecases/create_category_usecase.dart';
import '../../domain/usecases/update_category_usecase.dart';
import '../../domain/usecases/get_categories_usecase.dart';
import './categories_controller.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Category Form Controller
/// Controlador para crear y editar categorías
class CategoryFormController extends GetxController {
  final CreateCategoryUseCase createCategoryUseCase;
  final UpdateCategoryUseCase updateCategoryUseCase;
  final GetCategoriesUseCase getCategoriesUseCase;

  CategoryFormController({
    required this.createCategoryUseCase,
    required this.updateCategoryUseCase,
    required this.getCategoriesUseCase,
  });

  // Form key
  final formKey = GlobalKey<FormState>();

  // Category to edit (null for create mode)
  Category? categoryToEdit;
  bool get isEditMode => categoryToEdit != null;

  // Loading states
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxString errorMessage = ''.obs;

  // Form controllers
  late final TextEditingController nameController;
  late final TextEditingController descriptionController;
  late final TextEditingController imageUrlController;
  late final TextEditingController colorController;
  late final TextEditingController iconController;
  late final TextEditingController displayOrderController;

  // Observable states
  final RxBool isActive = true.obs;
  final Rx<String?> selectedParentId = Rx<String?>(null);
  final RxList<Category> availableParentCategories = <Category>[].obs;

  @override
  void onInit() {
    super.onInit();
    _initializeControllers();
    // Soporte para edit-by-arguments: si se navega con
    // `Get.toNamed(editCategory, arguments: <Category>)` o si la ruta
    // edit incluye `:id` y se pasa la entidad completa, la cargamos.
    final args = Get.arguments;
    if (args is Category) {
      categoryToEdit = args;
    }
    if (categoryToEdit != null) {
      _loadCategoryData();
    }
    _loadParentCategories();
  }

  @override
  void onClose() {
    _disposeControllers();
    super.onClose();
  }

  void _initializeControllers() {
    nameController = TextEditingController();
    descriptionController = TextEditingController();
    imageUrlController = TextEditingController();
    colorController = TextEditingController();
    iconController = TextEditingController();
    displayOrderController = TextEditingController(text: '0');
  }

  void _disposeControllers() {
    nameController.dispose();
    descriptionController.dispose();
    imageUrlController.dispose();
    colorController.dispose();
    iconController.dispose();
    displayOrderController.dispose();
  }

  void _loadCategoryData() {
    final category = categoryToEdit!;
    nameController.text = category.name;
    descriptionController.text = category.description;
    imageUrlController.text = category.imageUrl ?? '';
    colorController.text = category.color ?? '';
    iconController.text = category.icon ?? '';
    displayOrderController.text = category.displayOrder.toString();
    isActive.value = category.isActive;
    selectedParentId.value = category.parentId;
  }

  Future<void> _loadParentCategories() async {
    isLoading.value = true;

    final result = await getCategoriesUseCase(isActive: true);

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        isLoading.value = false;
      },
      (categories) {
        // Filtrar la categoría actual si estamos en modo edición
        if (isEditMode) {
          availableParentCategories.value = categories
              .where((cat) => cat.id != categoryToEdit!.id)
              .toList();
        } else {
          availableParentCategories.value = categories;
        }
        isLoading.value = false;
      },
    );
  }

  // Validation
  bool validate() {
    errorMessage.value = '';

    if (!formKey.currentState!.validate()) {
      errorMessage.value = 'Por favor completa todos los campos requeridos';
      return false;
    }

    // Validación cruzada: no permitir que la categoría sea su propio padre.
    // El backend también lo valida, pero acá fallamos rápido y damos un
    // mensaje claro al usuario sin pegarle al servidor.
    if (isEditMode &&
        selectedParentId.value != null &&
        selectedParentId.value == categoryToEdit!.id) {
      errorMessage.value = 'Una categoría no puede ser su propio padre';
      return false;
    }

    // Validación de color hex (si se completó): aceptamos #RRGGBB,
    // RRGGBB, #AARRGGBB o AARRGGBB. Si no parsea, avisamos al usuario.
    final hex = colorController.text.trim();
    if (hex.isNotEmpty && !_isValidHexColor(hex)) {
      errorMessage.value = 'Color hex inválido (ej: #FF5733 o FF5733)';
      return false;
    }

    return true;
  }

  /// Acepta formatos: `#RRGGBB`, `RRGGBB`, `#AARRGGBB`, `AARRGGBB`.
  bool _isValidHexColor(String value) {
    final clean = value.replaceAll('#', '');
    if (clean.length != 6 && clean.length != 8) return false;
    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean);
  }

  // Save category
  Future<void> saveCategory() async {
    if (!validate()) {
      AppSnackbar.show(
        'Validación',
        errorMessage.value,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return;
    }

    isSaving.value = true;
    errorMessage.value = '';

    try {
      if (isEditMode) {
        await _updateCategory();
      } else {
        await _createCategory();
      }
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _createCategory() async {
    final result = await createCategoryUseCase(
      name: nameController.text.trim(),
      description: descriptionController.text.trim(),
      imageUrl: imageUrlController.text.trim().isEmpty
          ? null
          : imageUrlController.text.trim(),
      color: colorController.text.trim().isEmpty
          ? null
          : colorController.text.trim(),
      icon: iconController.text.trim().isEmpty
          ? null
          : iconController.text.trim(),
      isActive: isActive.value,
      displayOrder: int.tryParse(displayOrderController.text) ?? 0,
      parentId: selectedParentId.value,
    );

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        AppSnackbar.show(
          'Error',
          failure.message,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
          duration: const Duration(seconds: 5),
        );
      },
      (category) {
        AppSnackbar.show(
          'Éxito',
          'Categoría creada exitosamente',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
        );

        // Refresh categories list
        try {
          final categoriesController = Get.find<CategoriesController>();
          categoriesController.refreshCategories();
        } catch (e) {
          // CategoriesController not found, that's ok
        }

        // Navigate back
        Navigator.of(Get.context!).pop(category);
      },
    );
  }

  Future<void> _updateCategory() async {
    final result = await updateCategoryUseCase(
      id: categoryToEdit!.id,
      name: nameController.text.trim(),
      description: descriptionController.text.trim(),
      imageUrl: imageUrlController.text.trim().isEmpty
          ? null
          : imageUrlController.text.trim(),
      color: colorController.text.trim().isEmpty
          ? null
          : colorController.text.trim(),
      icon: iconController.text.trim().isEmpty
          ? null
          : iconController.text.trim(),
      isActive: isActive.value,
      displayOrder: int.tryParse(displayOrderController.text) ?? 0,
      parentId: selectedParentId.value,
    );

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        AppSnackbar.show(
          'Error',
          failure.message,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
          duration: const Duration(seconds: 5),
        );
      },
      (category) {
        AppSnackbar.show(
          'Éxito',
          'Categoría actualizada exitosamente',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
        );

        // Refresh categories list
        try {
          final categoriesController = Get.find<CategoriesController>();
          categoriesController.refreshCategories();
        } catch (e) {
          // CategoriesController not found, that's ok
        }

        // Navigate back
        Get.back(result: category);
      },
    );
  }
}
