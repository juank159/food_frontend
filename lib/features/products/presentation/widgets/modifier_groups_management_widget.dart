import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/constants/modifier_enums.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/modifier.dart';
import '../../domain/entities/modifier_group.dart';
import '../controllers/product_form_controller.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/app_dialog.dart';
import '../../../../core/config/formatters/currency_formatter.dart';

/// Widget de gestión de grupos de modificadores dentro del form de producto.
///
/// Sólo se muestra en modo edición (cuando ya existe un `product.id`),
/// porque el backend exige `product_id` para crear el grupo. La UI permite:
///   * crear grupos (single/multiple, obligatorio, min/max)
///   * editar grupos
///   * eliminar grupos (con confirmación)
///   * asignar modificadores existentes (multi-select desde un bottom sheet)
///   * quitar modificadores asignados (chip "x")
class ModifierGroupsManagementWidget
    extends GetView<ProductFormController> {
  const ModifierGroupsManagementWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return AppFormSection(
      title: 'Grupos de modificadores',
      subtitle:
          'Agrupá los modificadores y definí cómo los selecciona el cliente.',
      icon: Icons.dynamic_form_outlined,
      accent: AppColors.info,
      children: [
        Obx(() {
          final groups = controller.modifierGroups;
          if (groups.isEmpty) {
            return _buildEmptyState(context);
          }
          return Column(
            children: [
              for (final group in groups)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ModifierGroupItem(
                    group: group,
                    onEdit: () => _showGroupDialog(context, group: group),
                    onDelete: () => _confirmDelete(context, group),
                    onAssignModifiers: () =>
                        _showAssignModifiersSheet(context, group),
                    onRemoveModifier: (m) =>
                        controller.removeModifier(
                      groupId: group.id,
                      modifierId: m.id,
                    ),
                  ),
                ),
            ],
          );
        }),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showGroupDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Agregar grupo'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(
                color: AppColors.info.withValues(alpha: 0.5),
              ),
              foregroundColor: AppColors.info,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.dynamic_form_outlined,
            size: 28,
            color: AppColors.textSecondary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 10),
          const Text(
            'Sin grupos de modificadores',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Creá un grupo para asignar modificadores y definir reglas de selección.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Diálogos / hojas
  // ---------------------------------------------------------------------------

  Future<void> _showGroupDialog(
    BuildContext context, {
    ModifierGroup? group,
  }) async {
    final isEdit = group != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: group?.name ?? '');
    final minController = TextEditingController(
      text: (group?.minSelections ?? 0).toString(),
    );
    final maxController = TextEditingController(
      text: group?.maxSelections?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: group?.description ?? '',
    );
    final selectionType =
        Rx<SelectionType>(group?.selectionType ?? SelectionType.single);
    final isRequired = RxBool(group?.isRequired ?? false);

    await AppDialog.show(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.dynamic_form_outlined,
                            color: AppColors.info,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isEdit ? 'Editar grupo' : 'Nuevo grupo',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Get.back<void>(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: appInputDecoration(
                        label: 'Nombre del grupo *',
                        hint: 'Ej: Tamaño, Extras, Salsas',
                        prefixIcon: Icons.label_outline,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'El nombre es requerido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      decoration: appInputDecoration(
                        label: 'Descripción (opcional)',
                        hint: 'Texto que verá el cliente',
                        prefixIcon: Icons.notes,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Obx(() => _SelectionTypeSelector(
                          value: selectionType.value,
                          onChanged: (v) => selectionType.value = v,
                        )),
                    const SizedBox(height: 12),
                    Obx(() => _RequiredToggle(
                          value: isRequired.value,
                          onChanged: (v) => isRequired.value = v,
                        )),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: minController,
                            keyboardType: TextInputType.number,
                            decoration: appInputDecoration(
                              label: 'Mínimo',
                              hint: '0',
                              prefixIcon: Icons.south,
                            ),
                            validator: (v) {
                              final n = int.tryParse((v ?? '').trim());
                              if (n == null || n < 0) {
                                return 'Inválido';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: maxController,
                            keyboardType: TextInputType.number,
                            decoration: appInputDecoration(
                              label: 'Máximo (opcional)',
                              hint: 'Sin límite',
                              prefixIcon: Icons.north,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final n = int.tryParse(v.trim());
                              if (n == null || n < 0) {
                                return 'Inválido';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Get.back<void>(),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Obx(() => FilledButton.icon(
                                onPressed:
                                    controller.isModifierGroupSaving.value
                                        ? null
                                        : () async {
                                            if (!formKey.currentState!
                                                .validate()) {
                                              return;
                                            }
                                            final min =
                                                int.tryParse(
                                                        minController.text
                                                            .trim()) ??
                                                    0;
                                            final maxText =
                                                maxController.text.trim();
                                            final max = maxText.isEmpty
                                                ? null
                                                : int.tryParse(maxText);
                                            final ok = isEdit
                                                ? await controller
                                                    .editModifierGroup(
                                                    groupId: group.id,
                                                    name: nameController.text
                                                        .trim(),
                                                    description:
                                                        descriptionController
                                                                .text
                                                                .trim()
                                                                .isEmpty
                                                            ? null
                                                            : descriptionController
                                                                .text
                                                                .trim(),
                                                    selectionType:
                                                        selectionType.value,
                                                    isRequired:
                                                        isRequired.value,
                                                    minSelections: min,
                                                    maxSelections: max,
                                                  )
                                                : await controller
                                                    .addModifierGroup(
                                                    name: nameController.text
                                                        .trim(),
                                                    description:
                                                        descriptionController
                                                                .text
                                                                .trim()
                                                                .isEmpty
                                                            ? null
                                                            : descriptionController
                                                                .text
                                                                .trim(),
                                                    selectionType:
                                                        selectionType.value,
                                                    isRequired:
                                                        isRequired.value,
                                                    minSelections: min,
                                                    maxSelections: max,
                                                  );
                                            if (ok) {
                                              Get.back<void>();
                                            }
                                          },
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: controller
                                        .isModifierGroupSaving.value
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Icon(Icons.check, size: 16),
                                label: Text(isEdit ? 'Guardar' : 'Crear'),
                              )),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    nameController.dispose();
    minController.dispose();
    maxController.dispose();
    descriptionController.dispose();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ModifierGroup group,
  ) async {
    final theme = Theme.of(context);
    await Get.dialog<void>(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Eliminar grupo'),
        content: Text(
          '¿Seguro que querés eliminar el grupo "${group.name}"?\nLos modificadores asociados no se borran.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () async {
              Get.back<void>();
              await controller.deleteModifierGroup(group.id);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAssignModifiersSheet(
    BuildContext context,
    ModifierGroup group,
  ) async {
    final available = await controller.fetchAvailableModifiers();
    if (!context.mounted) return;
    if (available.isEmpty) {
      AppSnackbar.show(
        'Sin modificadores',
        'No hay modificadores disponibles. Creá uno desde el módulo de modificadores.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.warning.withValues(alpha: 0.95),
        colorText: Colors.white,
      );
      return;
    }

    final assignedIds = group.modifiers.map((m) => m.id).toSet();
    final assignable =
        available.where((m) => !assignedIds.contains(m.id)).toList();

    final selected = <String>{}.obs;

    if (assignable.isEmpty) {
      AppSnackbar.show(
        'Todos asignados',
        'Todos los modificadores existentes ya están en este grupo.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.info.withValues(alpha: 0.95),
        colorText: Colors.white,
      );
      return;
    }

    await Get.bottomSheet<void>(
      Container(
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_link,
                    size: 18,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Asignar modificadores a "${group.name}"',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Get.back<void>(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: assignable.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (_, index) {
                  final m = assignable[index];
                  return Obx(() {
                    final isSelected = selected.contains(m.id);
                    return _AssignableModifierTile(
                      modifier: m,
                      selected: isSelected,
                      onTap: () {
                        if (isSelected) {
                          selected.remove(m.id);
                        } else {
                          selected.add(m.id);
                        }
                      },
                    );
                  });
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.back<void>(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Obx(() {
                        final count = selected.length;
                        final saving =
                            controller.isModifierGroupSaving.value;
                        return FilledButton.icon(
                          onPressed: count == 0 || saving
                              ? null
                              : () async {
                                  final ok =
                                      await controller.addModifiersToGroup(
                                    groupId: group.id,
                                    modifierIds: selected.toList(),
                                  );
                                  if (ok) {
                                    Get.back<void>();
                                  }
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: saving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.check, size: 16),
                          label: Text(
                            count == 0
                                ? 'Asignar'
                                : 'Asignar ($count)',
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
}

// ============================================================================
// Sub-widgets privados
// ============================================================================

class _ModifierGroupItem extends StatelessWidget {
  final ModifierGroup group;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAssignModifiers;
  final void Function(Modifier) onRemoveModifier;

  const _ModifierGroupItem({
    required this.group,
    required this.onEdit,
    required this.onDelete,
    required this.onAssignModifiers,
    required this.onRemoveModifier,
  });

  @override
  Widget build(BuildContext context) {
    final selectionLabel = group.allowsMultiple ? 'Múltiple' : 'Única';
    final selectionColor =
        group.allowsMultiple ? AppColors.info : AppColors.primary;
    final maxLabel = group.maxSelections?.toString() ?? '∞';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (group.description != null &&
                        group.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        group.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Editar grupo',
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                tooltip: 'Eliminar grupo',
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.error,
                ),
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Pill(
                label: selectionLabel,
                color: selectionColor,
                icon: group.allowsMultiple
                    ? Icons.checklist
                    : Icons.radio_button_checked,
              ),
              if (group.isRequired)
                const _Pill(
                  label: 'Obligatorio',
                  color: AppColors.error,
                  icon: Icons.priority_high,
                ),
              _Pill(
                label: '${group.minSelections} de $maxLabel selecciones',
                color: AppColors.textSecondary,
                icon: Icons.tune,
                neutral: true,
              ),
              _Pill(
                label: '${group.modifiers.length} modificadores',
                color: AppColors.accent,
                icon: Icons.list_alt_outlined,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (group.modifiers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Sin modificadores asignados',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in group.modifiers)
                  _ModifierChip(
                    modifier: m,
                    onRemove: () => onRemoveModifier(m),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onAssignModifiers,
              icon: const Icon(Icons.add_link, size: 16),
              label: const Text('Asignar modificadores'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.info,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool neutral;

  const _Pill({
    required this.label,
    required this.color,
    required this.icon,
    this.neutral = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = neutral
        ? AppColors.background
        : color.withValues(alpha: 0.10);
    final border = neutral
        ? AppColors.border
        : color.withValues(alpha: 0.3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModifierChip extends StatelessWidget {
  final Modifier modifier;
  final VoidCallback onRemove;

  const _ModifierChip({
    required this.modifier,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            modifier.name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          if (modifier.price > 0) ...[
            const SizedBox(width: 4),
            Text(
              '+${CurrencyFormatter.format(modifier.price)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary.withValues(alpha: 0.8),
              ),
            ),
          ],
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 14,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionTypeSelector extends StatelessWidget {
  final SelectionType value;
  final ValueChanged<SelectionType> onChanged;

  const _SelectionTypeSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6, left: 4),
          child: Text(
            'Tipo de selección',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _SelectionOption(
                label: 'Única',
                description: 'El cliente elige solo 1',
                icon: Icons.radio_button_checked,
                selected: value == SelectionType.single,
                onTap: () => onChanged(SelectionType.single),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SelectionOption(
                label: 'Múltiple',
                description: 'Permite varias',
                icon: Icons.checklist,
                selected: value == SelectionType.multiple,
                onTap: () => onChanged(SelectionType.multiple),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SelectionOption extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SelectionOption({
    required this.label,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.background,
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequiredToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _RequiredToggle({
    required this.value,
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
              color: value
                  ? AppColors.error.withValues(alpha: 0.5)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.priority_high,
                size: 18,
                color: value ? AppColors.error : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Obligatorio',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Switch.adaptive(
                value: value,
                activeColor: AppColors.error,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignableModifierTile extends StatelessWidget {
  final Modifier modifier;
  final bool selected;
  final VoidCallback onTap;

  const _AssignableModifierTile({
    required this.modifier,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.border;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.cardBackground,
          border: Border.all(color: color),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              size: 20,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    modifier.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    modifier.type.label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: modifier.price > 0
                    ? AppColors.primary.withValues(alpha: 0.10)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: modifier.price > 0
                      ? AppColors.primary.withValues(alpha: 0.25)
                      : AppColors.border,
                ),
              ),
              child: Text(
                modifier.price > 0
                    ? '+${CurrencyFormatter.format(modifier.price)}'
                    : 'Gratis',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: modifier.price > 0
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
