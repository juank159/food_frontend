import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/constants/modifier_enums.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/input_formatters.dart';
import '../../../../core/widgets/app_form_section.dart';
import '../../../../core/widgets/app_gradient_header.dart';
import '../controllers/modifier_form_controller.dart';

/// Formulario de creación/edición de modificador.
class ModifierFormPage extends GetView<ModifierFormController> {
  const ModifierFormPage({super.key});

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
                    _buildTypeAndPricingSection(),
                    const SizedBox(height: 14),
                    _buildAvailabilitySection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Obx(() => AppFormSubmitBar(
                  isSaving: controller.isSaving.value,
                  onCancel: () => Navigator.of(context).pop(),
                  onSave: controller.saveModifier,
                  saveLabel: controller.isEditMode
                      ? 'Actualizar'
                      : 'Crear modificador',
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return AppGradientHeader(
      title: controller.isEditMode
          ? 'Editar modificador'
          : 'Nuevo modificador',
      subtitle: 'Toppings, extras, sustituciones',
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
      subtitle: 'Nombre que verá el cliente y descripción interna.',
      icon: Icons.info_outline,
      children: [
        TextFormField(
          controller: controller.nameController,
          textCapitalization: TextCapitalization.words,
          decoration: appInputDecoration(
            label: 'Nombre *',
            hint: 'Queso extra, Sin tomate, etc.',
            prefixIcon: Icons.label_outline,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El nombre es requerido';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller.descriptionController,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 2,
          decoration: appInputDecoration(
            label: 'Descripción (opcional)',
            hint: 'Describe el modificador',
            prefixIcon: Icons.description_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeAndPricingSection() {
    return AppFormSection(
      title: 'Tipo y precio',
      subtitle: 'Cómo afecta el modificador al producto.',
      icon: Icons.swap_horiz,
      accent: AppColors.warning,
      children: [
        Obx(() => Row(
              children: [
                Expanded(
                  child: _TypePill(
                    icon: Icons.add_circle_outline,
                    label: 'Agregar',
                    selected: controller.selectedType.value ==
                        ModifierType.addition,
                    accent: AppColors.success,
                    onTap: () =>
                        controller.setModifierType(ModifierType.addition),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TypePill(
                    icon: Icons.remove_circle_outline,
                    label: 'Quitar',
                    selected: controller.selectedType.value ==
                        ModifierType.removal,
                    accent: AppColors.error,
                    onTap: () =>
                        controller.setModifierType(ModifierType.removal),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TypePill(
                    icon: Icons.swap_horiz,
                    label: 'Sustituir',
                    selected: controller.selectedType.value ==
                        ModifierType.substitution,
                    accent: AppColors.info,
                    onTap: () =>
                        controller.setModifierType(ModifierType.substitution),
                  ),
                ),
              ],
            )),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller.priceController,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                decoration: appInputDecoration(
                  label: 'Precio extra',
                  hint: '0',
                  prefixText: '\$',
                  prefixIcon: Icons.attach_money,
                  helperText: 'Cero si es gratis',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: controller.maxQuantityController,
                keyboardType: TextInputType.number,
                decoration: appInputDecoration(
                  label: 'Cant. máx.',
                  hint: 'Sin tope',
                  prefixIcon: Icons.exposure,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller.sortOrderController,
          keyboardType: TextInputType.number,
          decoration: appInputDecoration(
            label: 'Orden',
            hint: '0',
            prefixIcon: Icons.sort,
            helperText: 'Menor número aparece primero',
          ),
        ),
      ],
    );
  }

  Widget _buildAvailabilitySection() {
    return AppFormSection(
      title: 'Disponibilidad',
      icon: Icons.toggle_on_outlined,
      accent: AppColors.success,
      children: [
        Obx(() {
          final available = controller.isAvailable.value;
          return SwitchListTile.adaptive(
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            title: Text(
              available ? 'Disponible' : 'No disponible',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              available
                  ? 'Los clientes pueden seleccionar este modificador'
                  : 'Oculto al tomar pedidos',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            secondary: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color:
                    (available ? AppColors.success : AppColors.textSecondary)
                        .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                available ? Icons.check_circle : Icons.cancel_outlined,
                color:
                    available ? AppColors.success : AppColors.textSecondary,
                size: 18,
              ),
            ),
            value: available,
            onChanged: controller.toggleAvailability,
          );
        }),
      ],
    );
  }
}

class _TypePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _TypePill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent : AppColors.cardBackground,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent : AppColors.border,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : accent,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
