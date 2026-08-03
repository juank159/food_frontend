import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/input_formatters.dart';
import '../../../../core/utils/image_upload_service.dart';
import '../../../../core/widgets/barcode_scanner_page.dart';
import '../../../../core/widgets/app_form_section.dart';
import '../../../../core/widgets/app_gradient_header.dart';
import '../../../categories/presentation/bindings/categories_binding.dart';
import '../../../categories/presentation/controllers/categories_controller.dart';
import '../../domain/entities/product.dart';
import '../controllers/product_form_controller.dart';
import '../widgets/modifier_groups_management_widget.dart';
import '../widgets/variant_list_widget.dart';
import '../../../../core/utils/app_dialog.dart';

/// Formulario de creación/edición de producto. Cubre datos básicos,
/// precios, inventario, etiquetas/alérgenos y variantes.
class ProductFormPage extends GetView<ProductFormController> {
  final Product? productToEdit;

  const ProductFormPage({super.key, this.productToEdit});

  @override
  Widget build(BuildContext context) {
    // Activa el modo edición. `initForEditIfNeeded` es idempotente:
    // chequea internamente si ya estamos editando el mismo producto.
    // Sin esto el flujo "Editar producto" abría el form en modo CREAR
    // (vacío) porque el `onInit` del controller corría antes de que
    // este `build` setear el campo.
    if (productToEdit != null) {
      controller.initForEditIfNeeded(productToEdit);
    }

    // Interceptamos el pop (Android back, gesto, AppBar arrow) para
    // devolverle a la lista el producto recién creado si existe. Sin
    // esto, el operario crea un producto, toca atrás y la lista no se
    // entera del nuevo item hasta refrescar.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        controller.closeForm();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Form(
                  key: controller.formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildErrorBanner(),
                      _buildJustCreatedBanner(),
                      _buildBasicSection(context),
                      const SizedBox(height: 14),
                      _buildPricingSection(),
                      const SizedBox(height: 14),
                      _buildInventorySection(),
                      const SizedBox(height: 14),
                      _buildAdditionalSection(context),
                      const SizedBox(height: 14),
                      const VariantListWidget(),
                      // Grupos de modificadores: solo en modo edición
                      // (necesitan un product_id existente). Reactivo a
                      // `isEditModeRx` así aparece automáticamente tras
                      // crear el producto, sin recargar la pantalla.
                      Obx(() {
                        if (!controller.isEditModeRx.value) {
                          return const SizedBox.shrink();
                        }
                        return const Padding(
                          padding: EdgeInsets.only(top: 14),
                          child: ModifierGroupsManagementWidget(),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              Obx(() => AppFormSubmitBar(
                    isSaving: controller.isSaving.value,
                    onCancel: controller.closeForm,
                    onSave: controller.saveProduct,
                    saveLabel: controller.isEditModeRx.value
                        ? 'Actualizar producto'
                        : 'Crear producto',
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Obx(() => AppGradientHeader(
          title: controller.isEditModeRx.value
              ? 'Editar producto'
              : 'Nuevo producto',
          subtitle: 'Datos del menú, precio e inventario',
          leading: GestureDetector(
            onTap: controller.closeForm,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back,
                  color: Colors.white, size: 20),
            ),
          ),
        ));
  }

  /// Banner que aparece tras crear el producto desde modo "crear".
  /// Le indica al operario que ahora puede agregar opciones de
  /// personalización (grupos de modificadores) sin salir del form.
  Widget _buildJustCreatedBanner() {
    return Obx(() {
      if (!controller.didJustCreate.value) {
        return const SizedBox.shrink();
      }
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.success.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¡Producto creado!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Bajá hasta "Grupos de modificadores" para agregar opciones como "sin cebolla" o "extra queso".',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildErrorBanner() {
    return Obx(() {
      if (controller.errorMessage.value.isEmpty) {
        return const SizedBox.shrink();
      }
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                controller.errorMessage.value,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildBasicSection(BuildContext context) {
    // Garantizar el controller — el form se puede abrir directamente
    // sin pasar por la pantalla de categorías, en cuyo caso GetX no
    // lo tiene registrado aún. Llamamos el binding como fallback.
    if (!Get.isRegistered<CategoriesController>()) {
      CategoriesBinding().dependencies();
    }
    final categoriesController = Get.find<CategoriesController>();
    return AppFormSection(
      title: 'Información básica',
      subtitle: 'Datos visibles del producto.',
      icon: Icons.info_outline,
      children: [
        TextFormField(
          controller: controller.nameController,
          textCapitalization: TextCapitalization.words,
          decoration: appInputDecoration(
            label: 'Nombre del producto *',
            hint: 'Ej: Pizza Margarita',
            prefixIcon: Icons.restaurant_menu,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El nombre es requerido';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        // SKU: ahora es opcional. Si el operario lo deja vacío, el
        // controller lo auto-genera al guardar (ej. `HAM-1A3F8B2C`).
        // El botón "Auto" rellena el campo en vivo para que el operario
        // vea el valor antes de guardar.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: controller.skuController,
                textCapitalization: TextCapitalization.characters,
                decoration: appInputDecoration(
                  label: 'SKU',
                  hint: 'Dejar vacío para auto-generar',
                  prefixIcon: Icons.qr_code,
                  helperText: 'Si lo dejás vacío, se genera automáticamente',
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Botón "Auto" — chip filled que rellena el campo con un SKU
            // generado en base al nombre del producto.
            Padding(
              // Compensa el `helperText` para que el botón quede alineado
              // verticalmente con el TextField.
              padding: const EdgeInsets.only(top: 4),
              child: SizedBox(
                height: 48,
                child: FilledButton.tonalIcon(
                  onPressed: controller.fillAutoSku,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Auto'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Obx(() {
          return DropdownButtonFormField<String>(
            initialValue: controller.selectedCategoryId.value,
            decoration: appInputDecoration(
              label: 'Categoría *',
              hint: 'Seleccionar categoría',
              prefixIcon: Icons.category,
            ),
            items: categoriesController.categories.map((category) {
              return DropdownMenuItem(
                value: category.id,
                child: Text(category.name),
              );
            }).toList(),
            onChanged: (value) =>
                controller.selectedCategoryId.value = value,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Selecciona una categoría';
              }
              return null;
            },
          );
        }),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller.descriptionController,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
          decoration: appInputDecoration(
            label: 'Descripción *',
            hint: 'Describe el producto',
            prefixIcon: Icons.notes,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'La descripción es requerida';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        _buildPhotoPicker(context),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller.imageUrlController,
          keyboardType: TextInputType.url,
          decoration: appInputDecoration(
            label: 'O pegá una URL de imagen (opcional)',
            hint: 'https://…',
            prefixIcon: Icons.link,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller.barcodeController,
          decoration: appInputDecoration(
            label: 'Código de barras (opcional)',
            hint: '1234567890',
            prefixIcon: Icons.barcode_reader,
          ).copyWith(
            // Botón de escanear con la cámara — solo en mobile/tablet
            // (en desktop no hay cámara y se escribe a mano).
            suffixIcon: MediaQuery.of(context).size.width >= 900
                ? null
                : IconButton(
                    tooltip: 'Escanear con la cámara',
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () async {
                      final code = await scanBarcode(context);
                      if (code != null && code.isNotEmpty) {
                        controller.barcodeController.text = code;
                      }
                    },
                  ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller.preparationTimeController,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsSeparatorInputFormatter()],
          decoration: appInputDecoration(
            label: 'Tiempo de preparación (min)',
            hint: '15',
            prefixIcon: Icons.timer_outlined,
          ),
        ),
        const SizedBox(height: 12),
        // Toggle "Va a cocina/barra" — decide si el item aparece en la
        // comanda. Para botellas, snacks empacados y bebidas listas
        // el operario lo apaga: el item no sale en la comanda y, si
        // todos los items del ticket están en `false`, no se imprime
        // comanda en absoluto (no se desperdicia papel).
        Obx(() => _ToggleTile(
              icon: Icons.kitchen_outlined,
              label: controller.requiresPreparation.value
                  ? 'Va a cocina / barra'
                  : 'Entrega directa (sin comanda)',
              value: controller.requiresPreparation.value,
              accent: AppColors.primary,
              onChanged: (v) => controller.requiresPreparation.value = v,
            )),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Obx(() => _ToggleTile(
                    icon: Icons.check_circle_outline,
                    label: 'Disponible',
                    value: controller.isAvailable.value,
                    accent: AppColors.success,
                    onChanged: (v) => controller.isAvailable.value = v,
                  )),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Obx(() => _ToggleTile(
                    icon: Icons.star_border,
                    label: 'Destacado',
                    value: controller.isFeatured.value,
                    accent: AppColors.warning,
                    onChanged: (v) => controller.isFeatured.value = v,
                  )),
            ),
          ],
        ),
      ],
    );
  }

  /// Selector de foto del producto: vista previa + subir/cambiar/quitar.
  /// La foto se sube a Cloudinary y la URL queda en `imageUrlController`.
  /// Reacciona a cambios del controller (subida o URL pegada a mano).
  Widget _buildPhotoPicker(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller.imageUrlController,
      builder: (context, value, _) {
        final url = value.text.trim();
        final hasImg = url.isNotEmpty;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vista previa (o placeholder de cubiertos si no hay foto).
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasImg
                  ? CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SizedBox.shrink(),
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.restaurant_menu,
                        color: AppColors.textHint,
                        size: 34,
                      ),
                    )
                  : const Icon(
                      Icons.restaurant_menu,
                      color: AppColors.textHint,
                      size: 34,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Foto del producto',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Se muestra en la carta y al vender. Si no ponés, '
                    'aparece el ícono de cubiertos.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          final newUrl =
                              await ImageUploadService.pickAndUpload(context);
                          if (newUrl != null && newUrl.isNotEmpty) {
                            controller.imageUrlController.text = newUrl;
                          }
                        },
                        icon: Icon(
                          hasImg ? Icons.swap_horiz : Icons.add_a_photo_outlined,
                          size: 18,
                        ),
                        label: Text(hasImg ? 'Cambiar' : 'Subir foto'),
                      ),
                      if (hasImg) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Quitar foto',
                          icon: const Icon(Icons.delete_outline),
                          color: AppColors.error,
                          onPressed: () => controller.imageUrlController.clear(),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPricingSection() {
    return AppFormSection(
      title: 'Precios',
      subtitle: 'Precio de venta y costo (opcional para márgenes).',
      icon: Icons.attach_money,
      accent: AppColors.success,
      children: [
        TextFormField(
          controller: controller.basePriceController,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsSeparatorInputFormatter()],
          decoration: appInputDecoration(
            label: 'Precio base *',
            hint: '8.000',
            prefixIcon: Icons.attach_money,
            helperText: 'Formato automático con separadores',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El precio es requerido';
            }
            final price = NumberFormatHelper.parseFormattedInt(value);
            if (price == null || price < 0) {
              return 'Ingresa un precio válido';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller.costController,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsSeparatorInputFormatter()],
          decoration: appInputDecoration(
            label: 'Costo (opcional)',
            hint: '5.000',
            prefixIcon: Icons.shopping_cart_outlined,
            helperText: 'Costo de producción o adquisición',
          ),
        ),
      ],
    );
  }

  Widget _buildInventorySection() {
    return AppFormSection(
      title: 'Inventario',
      subtitle: 'Activá el control de stock si lleva inventario.',
      icon: Icons.inventory_2_outlined,
      accent: AppColors.info,
      children: [
        Obx(() => _ToggleTile(
              icon: Icons.inventory_2_outlined,
              label: 'Rastrear inventario',
              value: controller.trackInventory.value,
              accent: AppColors.info,
              onChanged: (v) => controller.trackInventory.value = v,
            )),
        Obx(() {
          if (!controller.trackInventory.value) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                TextFormField(
                  controller: controller.currentStockController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                  decoration: appInputDecoration(
                    label: 'Stock actual',
                    hint: '100',
                    prefixIcon: Icons.inventory,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controller.minStockAlertController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                  decoration: appInputDecoration(
                    label: 'Alerta de stock mínimo',
                    hint: '10',
                    prefixIcon: Icons.warning_amber_outlined,
                    helperText: 'Avisaremos cuando el stock baje de este valor',
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAdditionalSection(BuildContext context) {
    return AppFormSection(
      title: 'Información adicional',
      subtitle: 'Etiquetas y alérgenos para filtrado y avisos.',
      icon: Icons.label_outline,
      accent: AppColors.warning,
      children: [
        const Text(
          'Etiquetas',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Obx(() => Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...controller.tags.map(
                  (tag) => _ChipTag(
                    label: tag,
                    accent: AppColors.primary,
                    onDelete: () => controller.removeTag(tag),
                  ),
                ),
                _ChipAdd(
                  label: 'Agregar etiqueta',
                  onTap: () => _showAddTagDialog(context),
                ),
              ],
            )),
        const SizedBox(height: 14),
        const Text(
          'Alérgenos',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Obx(() => Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...controller.allergens.map(
                  (allergen) => _ChipTag(
                    label: allergen,
                    accent: AppColors.error,
                    onDelete: () => controller.removeAllergen(allergen),
                  ),
                ),
                _ChipAdd(
                  label: 'Agregar alérgeno',
                  onTap: () => _showAddAllergenDialog(context),
                ),
              ],
            )),
      ],
    );
  }

  void _showAddTagDialog(BuildContext context) => _showAddChipDialog(
        context: context,
        title: 'Agregar etiqueta',
        hint: 'Nombre de la etiqueta',
        onAdd: controller.addTag,
      );

  void _showAddAllergenDialog(BuildContext context) => _showAddChipDialog(
        context: context,
        title: 'Agregar alérgeno',
        hint: 'Nombre del alérgeno',
        onAdd: controller.addAllergen,
      );

  void _showAddChipDialog({
    required BuildContext context,
    required String title,
    required String hint,
    required void Function(String) onAdd,
  }) {
    final textController = TextEditingController();
    AppDialog.show(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(title),
        content: TextField(
          controller: textController,
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          decoration: appInputDecoration(label: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                onAdd(textController.text.trim());
                Navigator.of(context).pop();
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: value ? accent.withValues(alpha: 0.5) : AppColors.border,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: value ? accent : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: value ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ),
              Switch.adaptive(
                value: value,
                activeThumbColor: accent,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipTag extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback onDelete;
  const _ChipTag({
    required this.label,
    required this.accent,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDelete,
            child: Icon(
              Icons.close,
              size: 14,
              color: accent.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipAdd extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ChipAdd({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
