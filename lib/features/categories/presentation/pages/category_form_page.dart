import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/app_form_section.dart';
import '../../../../core/widgets/app_gradient_header.dart';
import '../controllers/category_form_controller.dart';

/// Formulario de creación/edición de categoría.
///
/// Mismo lenguaje visual que los otros forms: gradient header con back
/// y estado del save, secciones con `AppFormSection`, barra fija de
/// submit al pie.
class CategoryFormPage extends GetView<CategoryFormController> {
  const CategoryFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Form(
                key: controller.formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildBasicSection(),
                    const SizedBox(height: 14),
                    _buildCustomizationSection(),
                    const SizedBox(height: 14),
                    _buildStatusSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Obx(() => AppFormSubmitBar(
                  isSaving: controller.isSaving.value,
                  onCancel: () => Navigator.of(context).pop(),
                  onSave: controller.saveCategory,
                  saveLabel: controller.isEditMode
                      ? 'Actualizar'
                      : 'Crear categoría',
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return AppGradientHeader(
      title: controller.isEditMode ? 'Editar categoría' : 'Nueva categoría',
      subtitle: 'Organizá tu menú por agrupaciones',
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildBasicSection() {
    return AppFormSection(
      title: 'Información básica',
      subtitle: 'Nombre, descripción y categoría padre.',
      icon: Icons.info_outline,
      children: [
        TextFormField(
          controller: controller.nameController,
          decoration: appInputDecoration(
            label: 'Nombre *',
            hint: 'Ej: Bebidas, Postres',
            prefixIcon: Icons.label_outline,
          ),
          textCapitalization: TextCapitalization.words,
          maxLength: 255,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El nombre es requerido';
            }
            if (value.trim().length < 2) {
              return 'Mínimo 2 caracteres';
            }
            if (value.trim().length > 255) {
              return 'Máximo 255 caracteres';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        // Backend acepta description como opcional; lo mantenemos
        // recomendado pero no obligatorio para que el form no bloquee
        // al usuario si quiere una categoría rápida.
        TextFormField(
          controller: controller.descriptionController,
          decoration: appInputDecoration(
            label: 'Descripción',
            hint: 'Describe esta categoría',
            prefixIcon: Icons.description_outlined,
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 12),
        Obx(() => DropdownButtonFormField<String>(
              value: controller.selectedParentId.value,
              isExpanded: true,
              decoration: appInputDecoration(
                label: 'Categoría padre (opcional)',
                hint: 'Sin categoría padre (raíz)',
                prefixIcon: Icons.account_tree_outlined,
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Sin categoría padre (raíz)'),
                ),
                ...controller.availableParentCategories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category.id,
                    // Nombres largos podrían empujar el dropdown fuera
                    // del card en mobile; el `isExpanded` + ellipsis
                    // previene overflow.
                    child: Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
              validator: (value) {
                // No permitir self-as-parent (también validado en el
                // controller, pero redundancia ayuda a UX).
                if (controller.isEditMode &&
                    value != null &&
                    value == controller.categoryToEdit!.id) {
                  return 'No puede ser su propio padre';
                }
                return null;
              },
              onChanged: (value) {
                controller.selectedParentId.value = value;
              },
            )),
      ],
    );
  }

  Widget _buildCustomizationSection() {
    return AppFormSection(
      title: 'Personalización',
      subtitle: 'Imagen y orden — el color e icono son preview local.',
      icon: Icons.palette_outlined,
      accent: AppColors.warning,
      children: [
        TextFormField(
          controller: controller.imageUrlController,
          decoration: appInputDecoration(
            label: 'URL de imagen',
            hint: 'https://ejemplo.com/imagen.jpg',
            prefixIcon: Icons.image_outlined,
          ),
          keyboardType: TextInputType.url,
          validator: (value) {
            if (value == null || value.trim().isEmpty) return null;
            final v = value.trim();
            // Lazy validation: aceptamos http(s) o data URLs. El backend
            // tampoco hace validaciones de URL fuertes.
            final ok = v.startsWith('http://') ||
                v.startsWith('https://') ||
                v.startsWith('data:image/');
            return ok ? null : 'Debe empezar con http://, https:// o data:image/';
          },
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: controller.colorController,
                decoration: appInputDecoration(
                  label: 'Color (hex)',
                  hint: '#FF5733',
                  prefixIcon: Icons.palette_outlined,
                  helperText: 'Preview local',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  return _isValidHex(value.trim())
                      ? null
                      : 'Hex inválido (ej: #FF5733)';
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: controller.iconController,
                decoration: appInputDecoration(
                  label: 'Icono',
                  hint: 'restaurant',
                  prefixIcon: Icons.emoji_symbols,
                  helperText: 'Preview local',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller.displayOrderController,
          decoration: appInputDecoration(
            label: 'Orden de visualización',
            hint: '0',
            prefixIcon: Icons.sort,
            helperText: 'Menor número = aparece primero',
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.trim().isEmpty) return null;
            final n = int.tryParse(value.trim());
            if (n == null) return 'Debe ser un número entero';
            if (n < 0) return 'No puede ser negativo';
            return null;
          },
        ),
      ],
    );
  }

  /// Acepta `#RGB`, `RGB`, `#RRGGBB`, `RRGGBB`, `#AARRGGBB`, `AARRGGBB`.
  bool _isValidHex(String value) {
    final clean = value.replaceAll('#', '').replaceAll(' ', '');
    if (![3, 6, 8].contains(clean.length)) return false;
    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean);
  }

  Widget _buildStatusSection() {
    return AppFormSection(
      title: 'Estado',
      icon: Icons.toggle_on_outlined,
      accent: AppColors.success,
      children: [
        Obx(() {
          final active = controller.isActive.value;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SwitchListTile.adaptive(
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
              title: Text(
                active ? 'Categoría activa' : 'Categoría inactiva',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                active
                    ? 'Visible para los clientes en el menú'
                    : 'Oculta del menú',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (active ? AppColors.success : AppColors.textSecondary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  active ? Icons.visibility : Icons.visibility_off,
                  color: active ? AppColors.success : AppColors.textSecondary,
                  size: 18,
                ),
              ),
              value: active,
              onChanged: (value) => controller.isActive.value = value,
            ),
          );
        }),
      ],
    );
  }
}
