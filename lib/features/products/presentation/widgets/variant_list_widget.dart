// lib/features/products/presentation/widgets/variant_list_widget.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/app_dialog.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/modern_card.dart';
import '../controllers/product_form_controller.dart';
import 'variant_form_widget.dart';

/// Widget for managing the list of product variants
class VariantListWidget extends GetView<ProductFormController> {
  const VariantListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(Icons.tune, color: theme.colorScheme.primary, size: 24.0),
            SizedBox(width: 16.0),
            Text(
              'Variantes del Producto',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        SizedBox(height: 16.0),

        // Description
        Text(
          'Las variantes permiten ofrecer diferentes opciones del mismo producto (tamaños, tipos, etc.) con precios distintos.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),

        SizedBox(height: 16.0),

        // Variants list
        Obx(() {
          if (controller.variants.isEmpty) {
            return _buildEmptyState(context, theme);
          }

          return Column(
            children: [
              // Variants
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: controller.variants.length,
                itemBuilder: (context, index) {
                  final variant = controller.variants[index];
                  return VariantFormWidget(
                    variant: variant,
                    index: index,
                    onRemove: () => _confirmRemoveVariant(context, index),
                    onToggleDefault: () =>
                        controller.toggleVariantDefault(index),
                  );
                },
              ),

              SizedBox(height: 16.0),

              // Variants summary
              _buildVariantsSummary(context, theme),
            ],
          );
        }),

        SizedBox(height: 16.0),

        // Add variant button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: controller.addVariant,
            icon: const Icon(Icons.add),
            label: const Text('Agregar Variante'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return ModernCard(
      child: Column(
        children: [
          Icon(
            Icons.tune,
            size: 24.0,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          SizedBox(height: 16.0),
          Text(
            'Sin variantes',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16.0),
          Text(
            'Agrega variantes si este producto tiene diferentes opciones o tamaños',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVariantsSummary(BuildContext context, ThemeData theme) {
    final variantsCount = controller.variants.length;
    final defaultVariant = controller.variants.firstWhereOrNull(
      (v) => v.isDefault,
    );
    final availableCount = controller.variants
        .where((v) => v.isAvailable)
        .length;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Icon(
                  Icons.summarize,
                  size: 20.0,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12.0),
              Text(
                'Resumen de Variantes',
                style: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),

          // Stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.layers,
                  label: 'Total',
                  value: variantsCount.toString(),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.check_circle,
                  label: 'Disponibles',
                  value: availableCount.toString(),
                  color: AppColors.accent,
                ),
              ),
            ],
          ),

          // Default variant
          if (defaultVariant != null) ...[
            const SizedBox(height: 12.0),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: AppColors.accentLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.star, size: 18.0, color: AppColors.accent),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Variante por defecto',
                          style: TextStyle(
                            fontSize: 12.0,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          defaultVariant.nameController.text.isEmpty
                              ? 'Variante ${controller.variants.indexOf(defaultVariant) + 1}'
                              : defaultVariant.nameController.text,
                          style: const TextStyle(
                            fontSize: 14.0,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Warning if no default
          if (defaultVariant == null && variantsCount > 0) ...[
            const SizedBox(height: 12.0),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 20.0,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                      'Marca una variante como predeterminada',
                      style: TextStyle(
                        fontSize: 13.0,
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18.0, color: color),
          const SizedBox(width: 8.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.0,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18.0,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveVariant(BuildContext context, int index) {
    final theme = Theme.of(context);
    final variantName = controller.variants[index].nameController.text;

    AppDialog.show(
      AlertDialog(
        title: const Text('Eliminar Variante'),
        content: Text(
          variantName.isEmpty
              ? '¿Estás seguro de eliminar la Variante ${index + 1}?'
              : '¿Estás seguro de eliminar la variante "$variantName"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              controller.removeVariant(index);
              Get.back();
              AppSnackbar.show(
                'Variante Eliminada',
                'La variante ha sido eliminada correctamente',
                backgroundColor: theme.colorScheme.errorContainer,
                colorText: theme.colorScheme.onErrorContainer,
                duration: const Duration(seconds: 2),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
