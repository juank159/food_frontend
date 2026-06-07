import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/navigation_service.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_gradient_header.dart';
import '../../../../core/widgets/app_primary_action_bar.dart';
import '../../domain/entities/modifier.dart';
import '../controllers/modifiers_controller.dart';
import '../widgets/modifier_card.dart';

/// Modificadores — pantalla principal.
///
/// Cuando se monta como tab dentro de `ProductsPage`, pasamos `embedded: true`
/// para omitir el header propio. En modo standalone usamos `AppGradientHeader`
/// con KPIs (total, disponibles, sin stock).
class ModifiersPage extends StatelessWidget {
  final bool embedded;

  const ModifiersPage({super.key, this.embedded = false});

  // Getter lazy del controller — el binding del padre lo provee.
  ModifiersController get controller => Get.find<ModifiersController>();

  @override
  Widget build(BuildContext context) {
    if (embedded) {
      return _buildBody(context);
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
      bottomNavigationBar: AppPrimaryActionBar(
        label: 'Nuevo modificador',
        icon: Icons.add,
        onPressed: _navigateToCreateModifier,
      ),
    );
  }

  // ─────────────────────────── Header ───────────────────────────

  Widget _buildHeader() {
    return Obx(() {
      final total = controller.modifiers.length;
      final available = controller.modifiers
          .where((m) => m.isAvailable)
          .length;
      final unavailable = total - available;
      return AppGradientHeader(
        title: 'Modificadores',
        subtitle: 'Toppings, extras y sustituciones',
        leading: GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        trailing: Obx(() => _GradientToggleButton(
              active: controller.showOnlyAvailable.value,
              icon: Icons.filter_alt_outlined,
              activeIcon: Icons.filter_alt,
              tooltip: controller.showOnlyAvailable.value
                  ? 'Solo disponibles'
                  : 'Mostrar todos',
              onTap: controller.toggleAvailableFilter,
            )),
        chips: [
          AppKpiChip(
            icon: Icons.add_circle_outline,
            label: 'Total',
            value: total.toString(),
          ),
          AppKpiChip(
            icon: Icons.check_circle_outline,
            label: 'Disponibles',
            value: available.toString(),
          ),
          AppKpiChip(
            icon: Icons.remove_circle_outline,
            label: 'Sin stock',
            value: unavailable.toString(),
          ),
        ],
      );
    });
  }

  // ─────────────────────────── Body ───────────────────────────

  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: Obx(() {
            if (controller.isLoading.value && controller.modifiers.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.errorMessage.value.isNotEmpty &&
                controller.modifiers.isEmpty) {
              return AppErrorState(
                message: controller.errorMessage.value,
                onRetry: controller.refreshModifiers,
              );
            }
            if (controller.modifiers.isEmpty) {
              return AppEmptyState(
                icon: Icons.add_circle_outline,
                title: 'Aún no hay modificadores',
                message:
                    'Los modificadores son los extras o sustituciones que el cliente puede pedir sobre un producto (ej. queso extra, sin tomate).',
                actionLabel: 'Nuevo modificador',
                actionIcon: Icons.add,
                onAction: _navigateToCreateModifier,
              );
            }
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: controller.refreshModifiers,
              child: LayoutBuilder(builder: (context, constraints) {
                final w = constraints.maxWidth;
                final cross = w > 1200
                    ? 4
                    : w > 800
                        ? 3
                        : w > 600
                            ? 2
                            : 1;
                final cardW = (w - 16 * 2 - 16 * (cross - 1)) / cross;
                final aspect = (cardW / 220).clamp(0.7, 1.3);
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    childAspectRatio: aspect,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: controller.modifiers.length,
                  itemBuilder: (context, index) {
                    final modifier = controller.modifiers[index];
                    return ModifierCard(
                      modifier: modifier,
                      onTap: () => _showModifierDetails(context, modifier),
                      onEdit: () => _navigateToEditModifier(modifier),
                      onDelete: () => _confirmDelete(context, modifier),
                    );
                  },
                );
              }),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        textInputAction: TextInputAction.search,
        onSubmitted: controller.searchModifiers,
        decoration: InputDecoration(
          hintText: 'Buscar modificadores…',
          hintStyle: const TextStyle(
            color: AppColors.textHint,
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: AppColors.textSecondary,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── Modifier sheet ───────────────────────────

  void _showModifierDetails(BuildContext context, Modifier modifier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.add_circle_outline,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        modifier.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (modifier.description != null &&
                    modifier.description!.isNotEmpty) ...[
                  Text(
                    modifier.description!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                _detailRow('Tipo', _typeLabel(modifier.type.value)),
                _detailRow(
                  'Precio',
                  modifier.price > 0
                      ? CurrencyFormatter.format(modifier.price)
                      : 'Gratis',
                ),
                _detailRow(
                  'Disponibilidad',
                  modifier.isAvailable ? 'Disponible' : 'No disponible',
                ),
                if (modifier.maxQuantity != null)
                  _detailRow('Cantidad máxima', '${modifier.maxQuantity}'),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _navigateToEditModifier(modifier);
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _confirmDelete(context, modifier);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Eliminar'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'addition':
        return 'Agregar';
      case 'removal':
        return 'Quitar';
      case 'substitution':
        return 'Sustituir';
      default:
        return type;
    }
  }

  // ─────────────────────────── Confirmaciones / nav ───────────────────────────

  void _confirmDelete(BuildContext context, Modifier modifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Eliminar modificador'),
        content: Text(
          '¿Querés eliminar el modificador "${modifier.name}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await controller.deleteModifier(modifier.id);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _navigateToCreateModifier() async {
    final result = await NavigationService.toCreateModifier();
    if (result != null) controller.refreshModifiers();
  }

  void _navigateToEditModifier(Modifier modifier) async {
    final result =
        await NavigationService.toEditModifier(modifier: modifier);
    if (result != null) controller.refreshModifiers();
  }
}

class _GradientToggleButton extends StatelessWidget {
  final bool active;
  final IconData icon;
  final IconData activeIcon;
  final String tooltip;
  final VoidCallback onTap;

  const _GradientToggleButton({
    required this.active,
    required this.icon,
    required this.activeIcon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color:
            active ? Colors.white : Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              active ? activeIcon : icon,
              color: active ? AppColors.primary : Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
