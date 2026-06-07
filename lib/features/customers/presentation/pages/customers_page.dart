import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/routes/navigation_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/customer.dart';
import '../controllers/customers_controller.dart';

/// Customers Page — listado principal de clientes.
///
/// Mismo lenguaje visual que `CategoriesPage` y `OrdersPage`:
///   - Header gradient con KPIs (total / activos / nuevos del mes).
///   - Buscador con debounce (lo maneja el controller).
///   - Cards con stripe vertical, avatar tintado y chips compactos.
///   - Empty state coherente y RefreshIndicator para pull-to-refresh.
class CustomersPage extends GetView<CustomersController> {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
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
        label: 'Nuevo cliente',
        icon: Icons.person_add_alt_1,
        onPressed: () async {
          final result = await Get.toNamed(AppRoutes.createCustomer);
          if (result != null) controller.refreshAll();
        },
      ),
    );
  }

  // ─────────────────────────── Header ───────────────────────────

  Widget _buildHeader() {
    return Obx(() {
      return AppGradientHeader(
        title: 'Clientes',
        subtitle: 'Tu base de clientes y delivery',
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
        trailing: _GradientToggleButton(
          active: controller.showOnlyActive.value,
          icon: Icons.filter_alt_outlined,
          activeIcon: Icons.filter_alt,
          tooltip: controller.showOnlyActive.value
              ? 'Solo activos'
              : 'Mostrar todos',
          onTap: controller.toggleActiveFilter,
        ),
        chips: [
          AppKpiChip(
            icon: Icons.people_alt_outlined,
            label: 'Total',
            value: controller.totalCount.toString(),
          ),
          AppKpiChip(
            icon: Icons.verified_user_outlined,
            label: 'Activos',
            value: controller.activeCount.toString(),
          ),
          AppKpiChip(
            icon: Icons.fiber_new_outlined,
            label: 'Nuevos mes',
            value: controller.newThisMonthCount.toString(),
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
            if (controller.isLoading.value && !controller.hasCustomers) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.errorMessage.value.isNotEmpty &&
                !controller.hasCustomers) {
              return AppErrorState(
                message: controller.errorMessage.value,
                onRetry: controller.refreshAll,
              );
            }
            if (!controller.hasCustomers) {
              final hasFilter = controller.searchQuery.value.isNotEmpty ||
                  controller.showOnlyActive.value;
              return AppEmptyState(
                icon: Icons.people_alt_outlined,
                title: hasFilter
                    ? 'Sin resultados'
                    : 'Aún no hay clientes',
                message: hasFilter
                    ? 'Probá con otros términos o quitá los filtros para ver todos los clientes.'
                    : 'Sumá clientes para llevar registro de pedidos, direcciones de delivery y preferencias.',
                actionLabel:
                    hasFilter ? 'Limpiar filtros' : 'Nuevo cliente',
                actionIcon:
                    hasFilter ? Icons.clear_all : Icons.person_add_alt_1,
                onAction: () async {
                  if (hasFilter) {
                    controller.clearSearch();
                    if (controller.showOnlyActive.value) {
                      controller.toggleActiveFilter();
                    }
                  } else {
                    final result =
                        await Get.toNamed(AppRoutes.createCustomer);
                    if (result != null) controller.refreshAll();
                  }
                },
              );
            }
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: controller.refreshAll,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: controller.customers.length,
                itemBuilder: (context, index) {
                  final customer = controller.customers[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CustomerCard(
                      customer: customer,
                      onTap: () => _onCustomerTap(customer),
                      onEdit: () => _onEditCustomer(customer),
                      onDelete: () => _confirmDelete(context, customer),
                    ),
                  );
                },
              ),
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
        onChanged: controller.onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Buscar por nombre, teléfono o email…',
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

  // ─────────────────────────── Actions ───────────────────────────

  Future<void> _onCustomerTap(Customer customer) async {
    // Tap = ir al detalle. Si el detalle hizo cambios (editar/borrar
    // address, etc.) refrescamos la lista para reflejar contadores.
    final result =
        await NavigationService.toCustomerDetail<dynamic>(customer.id);
    if (result != null) controller.refreshAll();
  }

  Future<void> _onEditCustomer(Customer customer) async {
    final result = await Get.toNamed(
      AppRoutes.buildEditCustomer(customer.id),
      arguments: customer,
    );
    if (result != null) controller.refreshAll();
  }

  Future<void> _confirmDelete(BuildContext context, Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: Text(
          '¿Seguro querés eliminar a ${customer.fullName}? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.deleteCustomer(customer.id);
    }
  }
}

// ─────────────────────────── Widgets ───────────────────────────

/// Botón circular sobre el gradient con estado activo/inactivo.
/// Mismo widget que en `CategoriesPage` — privado al módulo para no
/// crear acoplamientos cruzados.
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

/// Card de cliente — stripe lateral, avatar con iniciales tintado, info
/// principal y chips compactos. Misma anatomía que `OrderCard` y
/// `CategoryCard` para mantener un único lenguaje visual.
class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomerCard({
    required this.customer,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        customer.isActive ? AppColors.primary : AppColors.textSecondary;
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(accent),
                        const SizedBox(height: 10),
                        _buildChipsRow(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color accent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildAvatar(accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customer.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 12,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      customer.phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _StatusPill(active: customer.isActive),
        const SizedBox(width: 4),
        _buildMenu(),
      ],
    );
  }

  Widget _buildAvatar(Color accent) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        customer.initials,
        style: TextStyle(
          color: accent,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Más opciones',
      icon: const Icon(
        Icons.more_vert,
        size: 18,
        color: AppColors.textSecondary,
      ),
      onSelected: (value) {
        if (value == 'edit') onEdit();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (_) => const [
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined,
                  size: 16, color: AppColors.textPrimary),
              SizedBox(width: 8),
              Text('Editar'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: AppColors.error),
              SizedBox(width: 8),
              Text('Eliminar', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChipsRow() {
    final chips = <Widget>[
      _MiniInfo(
        icon: Icons.shopping_bag_outlined,
        label: '${customer.totalOrders} '
            '${customer.totalOrders == 1 ? "orden" : "órdenes"}',
      ),
      _MiniInfo(
        icon: Icons.payments_outlined,
        label: _formatCurrency(customer.totalSpent),
      ),
      if (customer.email != null && customer.email!.isNotEmpty)
        _MiniInfo(
          icon: Icons.email_outlined,
          label: customer.email!,
        ),
      if (customer.lastOrderDate != null)
        _MiniInfo(
          icon: Icons.access_time,
          label: _relativeDate(customer.lastOrderDate!),
        ),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips,
    );
  }

  /// Alias del formatter global del proyecto. Antes había una
  /// implementación local manual — ahora delegamos al
  /// `CurrencyFormatter` centralizado para garantizar consistencia
  /// (símbolo `$` izquierda pegado, miles con punto, sin decimales).
  static String _formatCurrency(double value) =>
      CurrencyFormatter.format(value);

  static String _relativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'hoy';
    if (diff.inDays == 1) return 'ayer';
    if (diff.inDays < 7) return 'hace ${diff.inDays} días';
    if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return 'hace $weeks ${weeks == 1 ? "sem" : "sem"}';
    }
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

class _StatusPill extends StatelessWidget {
  final bool active;
  const _StatusPill({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            active ? 'Activo' : 'Inactivo',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniInfo({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
