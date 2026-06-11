import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/constants/modifier_enums.dart';
import '../../../../core/utils/input_formatters.dart';
import '../../domain/entities/modifier.dart';
import '../../domain/entities/modifier_group.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_variant.dart';
import '../../domain/usecases/add_modifiers_to_group_usecase.dart';
import '../../domain/usecases/create_modifier_group_usecase.dart';
import '../../domain/usecases/create_product_usecase.dart';
import '../../domain/usecases/create_variant_usecase.dart';
import '../../domain/usecases/delete_modifier_group_usecase.dart';
import '../../domain/usecases/delete_variant_usecase.dart';
import '../../domain/usecases/get_modifiers_usecase.dart';
import '../../domain/usecases/remove_modifier_from_group_usecase.dart';
import '../../domain/usecases/update_modifier_group_usecase.dart';
import '../../domain/usecases/update_product_usecase.dart';
import '../../domain/usecases/update_variant_usecase.dart';
import '../../../../core/utils/app_snackbar.dart';
import 'products_controller.dart';

/// Variant Form Data
/// Modelo temporal para variantes en el formulario
class VariantFormData {
  String? id; // null si es nueva, ID si es edición
  final TextEditingController nameController;
  final TextEditingController priceModifierController;
  final TextEditingController descriptionController;
  final TextEditingController skuController;
  bool isDefault;
  bool isAvailable;
  int sortOrder;

  VariantFormData({
    this.id,
    String? name,
    double? priceModifier,
    String? description,
    String? sku,
    this.isDefault = false,
    this.isAvailable = true,
    this.sortOrder = 0,
  })  : nameController = TextEditingController(text: name),
        // OJO: NO usar `priceModifier?.toString()` — produce "3000.0"
        // que el `ThousandsSeparatorInputFormatter` interpreta como
        // "3000.0" → al parsearlo con `parseFormattedInt` el `.` se
        // toma como separador de miles y devuelve 30000 (un cero
        // demás). Hay que pre-formatear con `formatNumber`.
        priceModifierController = TextEditingController(
          text: priceModifier != null && priceModifier != 0
              ? NumberFormatHelper.formatNumber(priceModifier.toInt())
              : '0',
        ),
        descriptionController = TextEditingController(text: description),
        skuController = TextEditingController(text: sku);

  factory VariantFormData.fromEntity(ProductVariant variant) {
    return VariantFormData(
      id: variant.id,
      name: variant.name,
      priceModifier: variant.priceModifier,
      description: variant.description,
      sku: variant.sku,
      isDefault: variant.isDefault,
      isAvailable: variant.isAvailable,
      sortOrder: variant.sortOrder,
    );
  }

  void dispose() {
    nameController.dispose();
    priceModifierController.dispose();
    descriptionController.dispose();
    skuController.dispose();
  }
}

/// Product Form Controller
/// Controlador para crear y editar productos con variantes
class ProductFormController extends GetxController {
  final CreateProductUseCase createProductUseCase;
  final UpdateProductUseCase updateProductUseCase;
  final CreateVariantUseCase createVariantUseCase;
  final UpdateVariantUseCase updateVariantUseCase;
  final DeleteVariantUseCase deleteVariantUseCase;
  final CreateModifierGroupUseCase createModifierGroupUseCase;
  final UpdateModifierGroupUseCase updateModifierGroupUseCase;
  final DeleteModifierGroupUseCase deleteModifierGroupUseCase;
  final AddModifiersToGroupUseCase addModifiersToGroupUseCase;
  final RemoveModifierFromGroupUseCase removeModifierFromGroupUseCase;
  final GetModifiersUseCase getModifiersUseCase;

  ProductFormController({
    required this.createProductUseCase,
    required this.updateProductUseCase,
    required this.createVariantUseCase,
    required this.updateVariantUseCase,
    required this.deleteVariantUseCase,
    required this.createModifierGroupUseCase,
    required this.updateModifierGroupUseCase,
    required this.deleteModifierGroupUseCase,
    required this.addModifiersToGroupUseCase,
    required this.removeModifierFromGroupUseCase,
    required this.getModifiersUseCase,
  });

  // Form key
  final formKey = GlobalKey<FormState>();

  // Product to edit (null for create mode)
  Product? productToEdit;
  bool get isEditMode => productToEdit != null;

  /// Espejo reactivo de `isEditMode`. Lo necesitamos porque tras crear un
  /// producto desde modo "crear", queremos que la UI se refresque a modo
  /// "editar" sin un re-mount (mostrar el widget de modifier groups,
  /// cambiar título y botón). Mantener `isEditMode` como getter sobre
  /// `productToEdit` deja la lógica simple, pero los Obx() necesitan un
  /// observable.
  final RxBool isEditModeRx = false.obs;

  /// Último producto guardado en esta sesión del form (null si el
  /// usuario abrió el form para editar y aún no guardó nada). Se setea
  /// tanto al crear como al actualizar. Lo usamos al cerrar el form
  /// para que la lista reciba siempre el último estado y refresque sin
  /// hacer un GET extra.
  Product? lastSavedProduct;

  /// `true` si el form recién creó el producto en esta sesión (vs.
  /// haber sido abierto para editar uno preexistente). Lo usamos para
  /// decidir si mostramos el banner verde "¡Producto creado!" que guía
  /// al operario hacia la sección de grupos de modificadores.
  final RxBool didJustCreate = false.obs;

  // Loading states
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxString errorMessage = ''.obs;

  // Form controllers
  late final TextEditingController nameController;
  late final TextEditingController skuController;
  late final TextEditingController descriptionController;
  late final TextEditingController basePriceController;
  late final TextEditingController costController;
  late final TextEditingController preparationTimeController;
  late final TextEditingController imageUrlController;
  late final TextEditingController barcodeController;
  late final TextEditingController currentStockController;
  late final TextEditingController minStockAlertController;

  // Observable states
  final Rx<String?> selectedCategoryId = Rx<String?>(null);
  final RxBool isAvailable = true.obs;
  final RxBool isFeatured = false.obs;
  final RxBool trackInventory = false.obs;
  final RxList<String> tags = <String>[].obs;
  final RxList<String> allergens = <String>[].obs;
  final RxList<String> images = <String>[].obs;

  // Variants management
  final RxList<VariantFormData> variants = <VariantFormData>[].obs;

  // Modifier groups management (solo disponible en modo edición —
  // necesitamos product_id para crear el grupo en el backend).
  final RxList<ModifierGroup> modifierGroups = <ModifierGroup>[].obs;
  final RxBool isModifierGroupSaving = false.obs;
  final RxBool isLoadingAvailableModifiers = false.obs;

  @override
  void onInit() {
    super.onInit();
    _initializeControllers();
    if (productToEdit != null) {
      _loadProductData();
      isEditModeRx.value = true;
    }
  }

  /// Activa el modo edición DESPUÉS de `onInit`.
  ///
  /// Necesario porque el `ProductFormPage` recibe `productToEdit` como
  /// constructor parameter y lo setea en `build`, que se ejecuta
  /// DESPUÉS del `onInit` del controller. Sin este método el
  /// `productToEdit` quedaba seteado pero `_loadProductData` nunca se
  /// llamaba y la página se mostraba en modo creación con campos
  /// vacíos.
  ///
  /// Idempotente: si ya estamos en modo edición con el mismo producto,
  /// no hace nada (porque `build` se llama múltiples veces).
  void initForEditIfNeeded(Product? product) {
    if (product == null) return;
    if (productToEdit?.id == product.id && isEditModeRx.value) return;
    productToEdit = product;
    _loadProductData();
    isEditModeRx.value = true;
  }

  @override
  void onClose() {
    _disposeControllers();
    for (var variant in variants) {
      variant.dispose();
    }
    super.onClose();
  }

  void _initializeControllers() {
    nameController = TextEditingController();
    skuController = TextEditingController();
    descriptionController = TextEditingController();
    basePriceController = TextEditingController(text: '0');
    costController = TextEditingController(text: '0');
    preparationTimeController = TextEditingController(text: '0');
    imageUrlController = TextEditingController();
    barcodeController = TextEditingController();
    currentStockController = TextEditingController(text: '0');
    minStockAlertController = TextEditingController(text: '0');
  }

  /// Genera un SKU único basado en las primeras letras del nombre del
  /// producto + timestamp en hex. Formato: `XXX-1A3F8B2C`.
  ///
  /// Si el nombre tiene "Hamburguesa Clásica" → `HAM-...`. Quita acentos,
  /// signos y espacios. Si el nombre está vacío usa `PROD-...`. El sufijo
  /// hex de timestamp colisiona en práctica con otro SKU del mismo tenant
  /// solo si dos productos se generan en el mismo milisegundo, lo cual
  /// es ignorable en un POS humano.
  String generateAutoSku() {
    final name = nameController.text.trim();
    String prefix;
    if (name.isEmpty) {
      prefix = 'PROD';
    } else {
      // Quita acentos y caracteres no alfanuméricos.
      final clean = name
          .replaceAll(RegExp(r'[áàäâã]'), 'a')
          .replaceAll(RegExp(r'[éèëê]'), 'e')
          .replaceAll(RegExp(r'[íìïî]'), 'i')
          .replaceAll(RegExp(r'[óòöôõ]'), 'o')
          .replaceAll(RegExp(r'[úùüû]'), 'u')
          .replaceAll(RegExp(r'[ÁÀÄÂÃ]'), 'A')
          .replaceAll(RegExp(r'[ÉÈËÊ]'), 'E')
          .replaceAll(RegExp(r'[ÍÌÏÎ]'), 'I')
          .replaceAll(RegExp(r'[ÓÒÖÔÕ]'), 'O')
          .replaceAll(RegExp(r'[ÚÙÜÛ]'), 'U')
          .replaceAll('ñ', 'n')
          .replaceAll('Ñ', 'N')
          .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '');
      final letters = clean.replaceAll(' ', '');
      prefix = letters.length >= 3
          ? letters.substring(0, 3).toUpperCase()
          : (letters.isEmpty ? 'PROD' : letters.toUpperCase().padRight(3, 'X'));
    }
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase();
    return '$prefix-${ts.substring(ts.length - 8)}';
  }

  /// Acción del botón "Auto" al lado del SKU. Pone el valor generado en
  /// el TextEditingController.
  void fillAutoSku() {
    skuController.text = generateAutoSku();
  }

  void _disposeControllers() {
    nameController.dispose();
    skuController.dispose();
    descriptionController.dispose();
    basePriceController.dispose();
    costController.dispose();
    preparationTimeController.dispose();
    imageUrlController.dispose();
    barcodeController.dispose();
    currentStockController.dispose();
    minStockAlertController.dispose();
  }

  void _loadProductData() {
    final product = productToEdit!;
    nameController.text = product.name;
    skuController.text = product.sku ?? '';
    descriptionController.text = product.description;
    // Pre-formatear los campos numéricos en formato es_CO con
    // separadores de miles. Si dejáramos `basePrice.toString()` →
    // "18000.0", el `ThousandsSeparatorInputFormatter` aplicaría su
    // regex al `.0` final, y al parsear devolvía 180000 (un cero de
    // más). Con `formatNumber(...)` el campo arranca con "18.000" y
    // round-trip es estable.
    basePriceController.text =
        NumberFormatHelper.formatNumber(product.basePrice.toInt());
    preparationTimeController.text = product.preparationTime.toString();
    imageUrlController.text = product.imageUrl ?? '';

    selectedCategoryId.value = product.categoryId;
    isAvailable.value = product.isAvailable;
    trackInventory.value = product.trackInventory;
    tags.value = List.from(product.tags);
    allergens.value = List.from(product.allergens);

    if (product.currentStock != null) {
      currentStockController.text =
          NumberFormatHelper.formatNumber(product.currentStock!);
    }
    if (product.minStockAlert != null) {
      minStockAlertController.text =
          NumberFormatHelper.formatNumber(product.minStockAlert!);
    }

    // Load variants
    variants.value = product.variants
        .map((v) => VariantFormData.fromEntity(v))
        .toList();

    // Load modifier groups (sólo informativos en modo edición)
    modifierGroups.value = List<ModifierGroup>.from(product.modifierGroups);
  }

  // Variant management methods
  void addVariant() {
    variants.add(VariantFormData(sortOrder: variants.length));
  }

  void removeVariant(int index) {
    if (index >= 0 && index < variants.length) {
      variants[index].dispose();
      variants.removeAt(index);
    }
  }

  void toggleVariantDefault(int index) {
    if (index >= 0 && index < variants.length) {
      // Unset all other defaults
      for (var i = 0; i < variants.length; i++) {
        variants[i].isDefault = i == index;
      }
      variants.refresh();
    }
  }

  // Tags and allergens management
  void addTag(String tag) {
    if (tag.isNotEmpty && !tags.contains(tag)) {
      tags.add(tag);
    }
  }

  void removeTag(String tag) {
    tags.remove(tag);
  }

  void addAllergen(String allergen) {
    if (allergen.isNotEmpty && !allergens.contains(allergen)) {
      allergens.add(allergen);
    }
  }

  void removeAllergen(String allergen) {
    allergens.remove(allergen);
  }

  // Validation
  bool validate() {
    errorMessage.value = '';

    if (!formKey.currentState!.validate()) {
      errorMessage.value = 'Por favor completa todos los campos requeridos';
      return false;
    }

    if (selectedCategoryId.value == null) {
      errorMessage.value = 'Selecciona una categoría';
      return false;
    }

    // Validate variants
    for (var i = 0; i < variants.length; i++) {
      final variant = variants[i];
      if (variant.nameController.text.trim().isEmpty) {
        errorMessage.value = 'Variante ${i + 1}: El nombre es requerido';
        return false;
      }
      final priceModifier = double.tryParse(variant.priceModifierController.text);
      if (priceModifier == null) {
        errorMessage.value = 'Variante ${i + 1}: Precio inválido';
        return false;
      }
    }

    return true;
  }

  // Save product
  Future<void> saveProduct() async {
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
        await _updateProduct();
      } else {
        await _createProduct();
      }
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _createProduct() async {
    // Si el operario no ingresó SKU, lo auto-generamos para que la
    // creación nunca falle por SKU vacío. Lo persistimos en el
    // controller para que el form muestre el valor generado.
    if (skuController.text.trim().isEmpty) {
      skuController.text = generateAutoSku();
    }
    final result = await createProductUseCase(
      name: nameController.text.trim(),
      basePrice: (NumberFormatHelper.parseFormattedInt(basePriceController.text) ?? 0).toDouble(),
      sku: skuController.text.trim(),
      categoryId: selectedCategoryId.value!,
      description: descriptionController.text.trim().isEmpty
          ? null
          : descriptionController.text.trim(),
      cost: costController.text.trim().isEmpty
          ? null
          : (NumberFormatHelper.parseFormattedInt(costController.text) ?? 0).toDouble(),
      preparationTime: NumberFormatHelper.parseFormattedInt(preparationTimeController.text),
      imageUrl: imageUrlController.text.trim().isEmpty
          ? null
          : imageUrlController.text.trim(),
      images: images.isEmpty ? null : images,
      barcode: barcodeController.text.trim().isEmpty
          ? null
          : barcodeController.text.trim(),
      isAvailable: isAvailable.value,
      isFeatured: isFeatured.value,
      tags: tags.isEmpty ? null : tags,
      allergens: allergens.isEmpty ? null : allergens,
      trackInventory: trackInventory.value,
      currentStock: trackInventory.value
          ? NumberFormatHelper.parseFormattedInt(currentStockController.text)
          : null,
      minStockAlert: trackInventory.value
          ? NumberFormatHelper.parseFormattedInt(minStockAlertController.text)
          : null,
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
      (product) async {
        // Create variants if any
        if (variants.isNotEmpty) {
          await _createVariantsForProduct(product.id);
        }

        // Transición a modo edición sin pop. La intención: dejar al
        // operario continuar agregando grupos de modifiers ("sin cebolla",
        // "extra queso", etc.) sin tener que volver a abrir el form.
        // - `productToEdit` se setea para habilitar el resto del flujo
        //   de edición (variant sync, modifier groups CRUD).
        // - `lastSavedProduct` queda guardado para devolverlo al pop
        //   final cuando el usuario cierre el form (back o cancel).
        // - `isEditModeRx` dispara los Obx() en la page para que se
        //   muestre el widget de modifier groups y cambien título/botón.
        // - `didJustCreate` activa el banner guía.
        productToEdit = product;
        lastSavedProduct = product;
        isEditModeRx.value = true;
        didJustCreate.value = true;

        // Refrescar lista global — el producto recién creado debe
        // aparecer en el ProductSelector del POS sin necesidad de
        // volver a la lista de productos y recargar a mano.
        _refreshGlobalProductsCache();

        AppSnackbar.show(
          '¡Producto creado!',
          'Ahora podés agregar opciones de personalización (sin cebolla, extra queso, etc.)',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
          duration: const Duration(seconds: 4),
          icon: const Icon(Icons.check_circle, color: Colors.white),
        );
      },
    );
  }

  /// Pop manual desde el form. Usar este método (en vez de `Get.back`
  /// directo) para que la lista reciba el último producto guardado en
  /// el `result` — sea recién creado o recién actualizado. Si el form
  /// se cierra sin guardar (modo edición y user solo miró), devolvemos
  /// `null` para no forzar refrescos innecesarios.
  void closeForm() {
    // Defensiva: si hubo cualquier guardado durante esta sesión del
    // form (incluyendo edición de variantes o modifier groups que se
    // hacen vía endpoints separados), refrescamos la caché global
    // antes de salir. Idempotente — si nada cambió no hace daño.
    if (lastSavedProduct != null) {
      _refreshGlobalProductsCache();
    }
    Navigator.of(Get.context!).pop(lastSavedProduct);
  }

  Future<void> _updateProduct() async {
    final result = await updateProductUseCase(
      id: productToEdit!.id,
      name: nameController.text.trim(),
      basePrice: (NumberFormatHelper.parseFormattedInt(basePriceController.text) ?? 0).toDouble(),
      sku: skuController.text.trim(),
      categoryId: selectedCategoryId.value,
      description: descriptionController.text.trim().isEmpty
          ? null
          : descriptionController.text.trim(),
      cost: costController.text.trim().isEmpty
          ? null
          : (NumberFormatHelper.parseFormattedInt(costController.text) ?? 0).toDouble(),
      preparationTime: NumberFormatHelper.parseFormattedInt(preparationTimeController.text),
      imageUrl: imageUrlController.text.trim().isEmpty
          ? null
          : imageUrlController.text.trim(),
      images: images.isEmpty ? null : images,
      barcode: barcodeController.text.trim().isEmpty
          ? null
          : barcodeController.text.trim(),
      isAvailable: isAvailable.value,
      isFeatured: isFeatured.value,
      tags: tags.isEmpty ? null : tags,
      allergens: allergens.isEmpty ? null : allergens,
      trackInventory: trackInventory.value,
      currentStock: trackInventory.value
          ? NumberFormatHelper.parseFormattedInt(currentStockController.text)
          : null,
      minStockAlert: trackInventory.value
          ? NumberFormatHelper.parseFormattedInt(minStockAlertController.text)
          : null,
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
      (product) async {
        // Update/create/delete variants
        await _syncVariants(product.id);

        // Mantener el form abierto pero registrar el último estado
        // guardado. Al cerrar, `closeForm()` lo devuelve a la lista.
        // No hacemos pop inmediato porque PopScope lo intercepta.
        productToEdit = product;
        lastSavedProduct = product;

        // Invalidar la caché global del `ProductsController` (si está
        // vivo). Esto cubre el caso "edito un producto desde detalle,
        // voy a crear una orden, y necesito ver el precio/nombre nuevo".
        // Sin esto el ProductSelectorWidget en `SellPage`
        // mostraba datos viejos hasta que el operario volvía a la
        // lista y refrescaba a mano.
        _refreshGlobalProductsCache();

        AppSnackbar.show(
          'Éxito',
          'Producto actualizado exitosamente',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
        );

        closeForm();
      },
    );
  }

  /// Si el `ProductsController` global está registrado en GetX (la
  /// pantalla de Productos lo crea como singleton), dispara su
  /// `refreshProducts()` para que cualquier pantalla que use ese
  /// controller (lista de productos, ProductSelector del POS, etc.)
  /// vea los cambios inmediatamente.
  ///
  /// Fire-and-forget: el form no espera por el refresh; si tarda no
  /// bloquea el cierre. Si el controller NO está registrado (caso
  /// raro: form abierto sin haber pasado por la lista), no hace nada.
  void _refreshGlobalProductsCache() {
    if (Get.isRegistered<ProductsController>()) {
      Get.find<ProductsController>().refreshProducts();
    }
  }

  Future<void> _createVariantsForProduct(String productId) async {
    for (var variantData in variants) {
      final priceModifier = (NumberFormatHelper.parseFormattedInt(variantData.priceModifierController.text) ?? 0).toDouble();

      await createVariantUseCase(
        productId: productId,
        name: variantData.nameController.text.trim(),
        priceModifier: priceModifier,
        description: variantData.descriptionController.text.trim().isEmpty
            ? null
            : variantData.descriptionController.text.trim(),
        isDefault: variantData.isDefault,
        sortOrder: variantData.sortOrder,
        isAvailable: variantData.isAvailable,
        sku: variantData.skuController.text.trim().isEmpty
            ? null
            : variantData.skuController.text.trim(),
      );
    }
  }

  Future<void> _syncVariants(String productId) async {
    // This is simplified - in production you'd track which are new/updated/deleted
    // For now, just create new variants
    for (var variantData in variants) {
      if (variantData.id == null) {
        // New variant
        final priceModifier = (NumberFormatHelper.parseFormattedInt(variantData.priceModifierController.text) ?? 0).toDouble();

        await createVariantUseCase(
          productId: productId,
          name: variantData.nameController.text.trim(),
          priceModifier: priceModifier,
          description: variantData.descriptionController.text.trim().isEmpty
              ? null
              : variantData.descriptionController.text.trim(),
          isDefault: variantData.isDefault,
          sortOrder: variantData.sortOrder,
          isAvailable: variantData.isAvailable,
          sku: variantData.skuController.text.trim().isEmpty
              ? null
              : variantData.skuController.text.trim(),
        );
      } else {
        // Update existing variant
        final priceModifier = (NumberFormatHelper.parseFormattedInt(variantData.priceModifierController.text) ?? 0).toDouble();

        await updateVariantUseCase(
          variantId: variantData.id!,
          name: variantData.nameController.text.trim(),
          priceModifier: priceModifier,
          description: variantData.descriptionController.text.trim().isEmpty
              ? null
              : variantData.descriptionController.text.trim(),
          isDefault: variantData.isDefault,
          sortOrder: variantData.sortOrder,
          isAvailable: variantData.isAvailable,
          sku: variantData.skuController.text.trim().isEmpty
              ? null
              : variantData.skuController.text.trim(),
        );
      }
    }
  }

  // ==========================================================================
  // Modifier groups management
  // ==========================================================================

  /// Crear un nuevo grupo de modificadores para el producto en edición.
  /// Devuelve `true` si la operación fue exitosa.
  Future<bool> addModifierGroup({
    required String name,
    required SelectionType selectionType,
    required bool isRequired,
    int minSelections = 0,
    int? maxSelections,
    String? description,
    List<String>? modifierIds,
  }) async {
    if (productToEdit == null) {
      _showError('Guardá el producto antes de crear grupos de modificadores');
      return false;
    }

    isModifierGroupSaving.value = true;
    try {
      final result = await createModifierGroupUseCase(
        name: name,
        productId: productToEdit!.id,
        description: description,
        selectionType: selectionType,
        minSelections: minSelections,
        maxSelections: maxSelections,
        isRequired: isRequired,
        sortOrder: modifierGroups.length,
        modifierIds: modifierIds,
      );

      return result.fold(
        (failure) {
          _showError(failure.message);
          return false;
        },
        (group) {
          modifierGroups.add(group);
          _showSuccess('Grupo "${group.name}" creado');
          return true;
        },
      );
    } finally {
      isModifierGroupSaving.value = false;
    }
  }

  /// Editar un grupo existente.
  Future<bool> editModifierGroup({
    required String groupId,
    String? name,
    SelectionType? selectionType,
    bool? isRequired,
    int? minSelections,
    int? maxSelections,
    String? description,
  }) async {
    isModifierGroupSaving.value = true;
    try {
      final result = await updateModifierGroupUseCase(
        id: groupId,
        name: name,
        description: description,
        selectionType: selectionType,
        minSelections: minSelections,
        maxSelections: maxSelections,
        isRequired: isRequired,
      );

      return result.fold(
        (failure) {
          _showError(failure.message);
          return false;
        },
        (group) {
          final idx = modifierGroups.indexWhere((g) => g.id == groupId);
          if (idx >= 0) {
            // Preservamos los modificadores actuales si el backend no los devuelve.
            final preservedModifiers = group.modifiers.isEmpty
                ? modifierGroups[idx].modifiers
                : group.modifiers;
            modifierGroups[idx] = ModifierGroup(
              id: group.id,
              productId: group.productId,
              name: group.name,
              description: group.description,
              selectionType: group.selectionType,
              minSelections: group.minSelections,
              maxSelections: group.maxSelections,
              isRequired: group.isRequired,
              sortOrder: group.sortOrder,
              isActive: group.isActive,
              modifiers: preservedModifiers,
            );
          }
          _showSuccess('Grupo actualizado');
          return true;
        },
      );
    } finally {
      isModifierGroupSaving.value = false;
    }
  }

  /// Eliminar un grupo de modificadores.
  Future<bool> deleteModifierGroup(String groupId) async {
    isModifierGroupSaving.value = true;
    try {
      final result = await deleteModifierGroupUseCase(groupId);
      return result.fold(
        (failure) {
          _showError(failure.message);
          return false;
        },
        (_) {
          modifierGroups.removeWhere((g) => g.id == groupId);
          _showSuccess('Grupo eliminado');
          return true;
        },
      );
    } finally {
      isModifierGroupSaving.value = false;
    }
  }

  /// Asociar uno o más modificadores existentes a un grupo.
  Future<bool> addModifiersToGroup({
    required String groupId,
    required List<String> modifierIds,
  }) async {
    if (modifierIds.isEmpty) return false;

    isModifierGroupSaving.value = true;
    try {
      final result = await addModifiersToGroupUseCase(
        groupId: groupId,
        modifierIds: modifierIds,
      );

      return result.fold(
        (failure) {
          _showError(failure.message);
          return false;
        },
        (group) {
          final idx = modifierGroups.indexWhere((g) => g.id == groupId);
          if (idx >= 0) {
            modifierGroups[idx] = group;
          }
          _showSuccess('Modificadores asignados');
          return true;
        },
      );
    } finally {
      isModifierGroupSaving.value = false;
    }
  }

  /// Quitar un modificador de un grupo.
  Future<bool> removeModifier({
    required String groupId,
    required String modifierId,
  }) async {
    isModifierGroupSaving.value = true;
    try {
      final result = await removeModifierFromGroupUseCase(
        groupId: groupId,
        modifierId: modifierId,
      );

      return result.fold(
        (failure) {
          _showError(failure.message);
          return false;
        },
        (_) {
          final idx = modifierGroups.indexWhere((g) => g.id == groupId);
          if (idx >= 0) {
            final current = modifierGroups[idx];
            modifierGroups[idx] = ModifierGroup(
              id: current.id,
              productId: current.productId,
              name: current.name,
              description: current.description,
              selectionType: current.selectionType,
              minSelections: current.minSelections,
              maxSelections: current.maxSelections,
              isRequired: current.isRequired,
              sortOrder: current.sortOrder,
              isActive: current.isActive,
              modifiers:
                  current.modifiers.where((m) => m.id != modifierId).toList(),
            );
          }
          return true;
        },
      );
    } finally {
      isModifierGroupSaving.value = false;
    }
  }

  /// Cargar todos los modificadores disponibles para asignar a un grupo.
  Future<List<Modifier>> fetchAvailableModifiers() async {
    isLoadingAvailableModifiers.value = true;
    try {
      final result = await getModifiersUseCase();
      return result.fold(
        (failure) {
          _showError(failure.message);
          return <Modifier>[];
        },
        (modifiers) => modifiers,
      );
    } finally {
      isLoadingAvailableModifiers.value = false;
    }
  }

  void _showError(String message) {
    AppSnackbar.show(
      'Error',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Get.theme.colorScheme.error,
      colorText: Get.theme.colorScheme.onError,
      duration: const Duration(seconds: 4),
    );
  }

  void _showSuccess(String message) {
    AppSnackbar.show(
      'Éxito',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Get.theme.colorScheme.primary,
      colorText: Get.theme.colorScheme.onPrimary,
      duration: const Duration(seconds: 2),
    );
  }
}
