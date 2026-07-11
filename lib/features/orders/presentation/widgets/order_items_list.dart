import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../core/config/constants/modifier_enums.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/modern_card.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/domain/entities/product_variant.dart';
import '../../../products/presentation/bindings/products_binding.dart';
import '../../../products/presentation/controllers/products_controller.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_item.dart';
import '../../domain/entities/order_item_modifier.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/utils/input_formatters.dart';
import '../controllers/order_detail_controller.dart';

/// Order Items List
///
/// Muestra los items de la orden con su estado individual (pendiente /
/// en cocina / listo / entregado) y permite al mesero marcar cada item
/// como entregado a la mesa con un tap. El backend auto-avanza la
/// orden completa cuando todos los items llegaron al final.
///
/// Si recibe un [controller], la lista entra en "modo interactivo":
/// muestra el progreso de entrega + botón "Entregar todo lo listo" y
/// cada item se vuelve tappable. Sin controller funciona como vista
/// pasiva (igual que antes).
class OrderItemsList extends StatelessWidget {
  final Order order;
  final OrderDetailController? controller;

  const OrderItemsList({
    super.key,
    required this.order,
    this.controller,
  });

  bool get _interactive => controller != null;

  /// Permisos según rol — debe ser el mismo que aplica el backend en
  /// `OrdersService.assertItemStatusTransitionAllowed`. Mantener ambos
  /// lados en sync evita que el frontend muestre acciones que el
  /// backend va a rechazar con 403.
  _ItemPermissions get _permissions =>
      _ItemPermissions.fromRole(_currentRoleCode, order);

  String? get _currentRoleCode {
    if (!Get.isRegistered<AuthController>()) return null;
    return Get.find<AuthController>().currentUser?.roleCode;
  }

  /// La interacción de entrega solo tiene sentido mientras la orden
  /// está activa. Si ya está completed/cancelled, mostramos el estado
  /// pero no permitimos tap. Además el rol debe poder hacer al menos
  /// una transición — si no, ocultamos toda la UI interactiva.
  bool get _canInteract =>
      _interactive && order.isActive && _permissions.hasAnyTransition;

  bool get _canEdit =>
      controller != null &&
      order.isActive &&
      ['admin', 'manager', 'cashier', 'waiter']
          .contains(_currentRoleCode);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ModernCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            // Sólo mostramos el progress/botón bulk si el rol PUEDE
            // marcar items como entregados (mesero/cashier/delivery/
            // admin/manager). A cocina/bartender no les sirve este
            // bloque — para ellos el flujo de "marcar listo" vive en
            // el KDS.
            if (_canInteract && _permissions.canDeliver) ...[
              const SizedBox(height: 12),
              _DeliveryProgress(
                order: order,
                controller: controller!,
              ),
            ],
            const Divider(height: 24),

            // Items
            ...order.items.map((item) => _buildOrderItem(context, item)),

            if (_canEdit) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: _AddItemButton(
                      icon: Icons.inventory_2_outlined,
                      label: 'Agregar producto',
                      color: AppColors.primary,
                      onTap: () => _showAddProductSheet(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AddItemButton(
                      icon: Icons.add_circle_outline,
                      label: 'Agregar adicional',
                      color: AppColors.warning,
                      onTap: () => _showAddItemSheet(context),
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 24),

            // Totals
            _buildTotalRow(theme, 'Subtotal', order.subtotal),
            if (order.effectiveDiscount > 0) ...[
              const SizedBox(height: 8),
              _buildTotalRow(
                theme,
                'Descuento',
                -order.effectiveDiscount,
                color: Colors.green,
              ),
            ],
            if (order.taxAmount > 0) ...[
              const SizedBox(height: 8),
              _buildTotalRow(theme, 'Impuestos', order.taxAmount),
            ],
            if (order.deliveryFee > 0) ...[
              const SizedBox(height: 8),
              _buildTotalRow(theme, 'Envío', order.deliveryFee),
            ],
            if (order.tipAmount > 0) ...[
              const SizedBox(height: 8),
              _buildTotalRow(theme, 'Propina', order.tipAmount),
            ],

            const Divider(height: 16),

            _buildTotalRow(
              theme,
              'Total',
              order.totalAmount,
              isHighlight: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.restaurant_menu,
          color: theme.colorScheme.primary,
          size: 20,
        ),
        const SizedBox(width: 8),
        // Expanded (no Spacer) para que el título se achique con ellipsis
        // en pantallas chicas en vez de empujar el chip y desbordar.
        Expanded(
          child: Text(
            'Items de la orden',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            '${order.totalItems} items',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItem(BuildContext context, OrderItem item) {
    final theme = Theme.of(context);
    final status = _ItemStatusVisuals.of(item);
    final nextStatus = _nextStatusForRole(item);
    final perms = _permissions;
    final canForward = _canInteract && nextStatus != null;
    final canUndoDelivery =
        _canInteract && item.isDelivered && perms.canDeliver;

    // Layout pasivo del item — el ÚNICO punto tappable es el círculo
    // grande (52x52) a la derecha. Tocar el nombre o el precio no
    // hace nada. Esto evita marcar accidentalmente algo al hacer
    // scroll y deja el tap target claro y enorme.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: item.isDelivered
            ? AppColors.success.withValues(alpha: 0.07)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isDelivered
              ? AppColors.success.withValues(alpha: 0.22)
              : Colors.transparent,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildLeading(theme, item),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: item.isDelivered
                        ? TextDecoration.lineThrough
                        : null,
                    color: item.isDelivered
                        ? theme.colorScheme.onSurfaceVariant
                        : null,
                  ),
                ),
                if (item.variantName != null &&
                    item.variantName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.variantName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                _StatusBadge(visuals: status),
                if (item.hasModifiers) ...[
                  const SizedBox(height: 6),
                  ...item.modifiers
                      .map((m) => _buildModifierLine(theme, m)),
                ],
                if (item.specialInstructions != null &&
                    item.specialInstructions!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.sticky_note_2_outlined,
                        size: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.specialInstructions!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${CurrencyFormatter.format(item.unitPrice)} c/u · '
                  '${CurrencyFormatter.format(item.subtotal)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (_canEdit) ...[
            Obx(() {
              final busy = controller!.updatingItemIds.contains(item.id);
              return IconButton(
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline, size: 20),
                color: Theme.of(context).colorScheme.error,
                tooltip: 'Eliminar',
                onPressed: busy
                    ? null
                    : () => _onDeleteTap(context, item),
              );
            }),
          ],
          const SizedBox(width: 4),
          _DeliveryTapTarget(
            item: item,
            nextStatus: nextStatus,
            canForward: canForward,
            canUndoDelivery: canUndoDelivery,
            canShowSheet: _canInteract,
            onTap: () => _onItemTap(context, item),
            onLongPress: () => _onItemLongPress(context, item),
          ),
        ],
      ),
    );
  }

  /// Badge de cantidad — solo visual (el spinner de "guardando" vive
  /// dentro del círculo tappable a la derecha, donde el usuario está
  /// mirando cuando ejecuta la acción).
  Widget _buildLeading(ThemeData theme, OrderItem item) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          '${item.quantity}x',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  /// Tap corto = acción primaria del item:
  ///   - si NO está entregado y el rol puede avanzarlo → avanza al
  ///     siguiente estado **sin diálogo** (1 tap = listo). Es la
  ///     acción de alta frecuencia del mesero.
  ///   - si YA está entregado y el rol puede entregar → muestra
  ///     dialog de confirmación para **deshacer la entrega**. Esto
  ///     evita reverts accidentales si el mesero toca un item ya
  ///     marcado al pasar el dedo por la lista.
  void _onItemTap(BuildContext context, OrderItem item) async {
    if (controller == null) return;

    if (item.isDelivered) {
      await _confirmUndoDelivery(context, item);
      return;
    }

    final next = _nextStatusForRole(item);
    if (next == null) return;

    HapticFeedback.lightImpact();
    final ok = await controller!.updateItemStatus(
      itemId: item.id,
      newStatus: next,
    );
    if (ok && context.mounted) {
      // Pequeño "ack" háptico de confirmación. No abrimos snackbar
      // para no inundar al mesero que está marcando varios seguidos
      // — la card ya cambia de color sola.
      HapticFeedback.selectionClick();
    }
  }

  /// Dialog para confirmar "deshacer entrega". El revert no es
  /// destructivo (no borra datos, solo vuelve el item a `ready`),
  /// pero queremos que sea deliberado — un tap accidental no debería
  /// revertir lo que ya fue entregado físicamente a la mesa.
  Future<void> _confirmUndoDelivery(
    BuildContext context,
    OrderItem item,
  ) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => _UndoDeliveryDialog(item: item),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final ok = await controller!.updateItemStatus(
      itemId: item.id,
      newStatus: OrderStatus.ready,
    );
    if (ok) HapticFeedback.selectionClick();
  }

  /// Long press = bottom sheet con acciones avanzadas. Las del flujo
  /// normal (avanzar / deshacer entrega) ya están cubiertas por el tap
  /// simple, así que acá solo abrimos si quedan acciones edge — "Marcar
  /// listo desde pending" o "Devolver a cocina".
  void _onItemLongPress(BuildContext context, OrderItem item) {
    if (controller == null) return;
    final perms = _permissions;
    final hasAdvancedActions =
        // "Marcar como listo" (solo si el rol puede + el item está
        // antes de ready y no entregado)
        (!item.isReady && !item.isDelivered && perms.canMarkReady) ||
            // "Devolver a cocina" (solo cocina/bartender/admin)
            (item.status != OrderStatus.preparing &&
                !item.isDelivered &&
                perms.canMarkPreparing);
    if (!hasAdvancedActions) return;

    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ItemActionsSheet(
        item: item,
        controller: controller!,
        permissions: perms,
      ),
    );
  }

  /// Devuelve el próximo status al que el ROL puede llevar al item con
  /// UN SOLO tap, o null si el rol no tiene nada útil que hacer en
  /// este item.
  ///
  /// La regla es deliberadamente simple para que el operario haga
  /// **un tap por item**, no dos:
  ///   - Si el rol puede entregar (mesero/cashier/admin/manager/
  ///     delivery): tap → delivered. Saltamos ready, sin importar el
  ///     estado previo. Si la cocina nunca marcó ready, el backend
  ///     setea `prepared_at` automáticamente al saltar.
  ///   - Si el rol solo puede marcar listo (cocina/bartender): tap →
  ///     ready.
  OrderStatus? _nextStatusForRole(OrderItem item) {
    if (item.isDelivered ||
        item.status == OrderStatus.completed ||
        item.status == OrderStatus.cancelled) {
      return null;
    }
    final perms = _permissions;

    // El mesero/cashier va siempre directo a delivered — no le hace
    // ningún favor pasar por ready primero (sería un doble tap inútil).
    if (perms.canDeliver) return OrderStatus.delivered;

    // La cocina/bartender marca listo. Si el item ya está ready no
    // tiene nada que hacer.
    if (perms.canMarkReady && !item.isReady) {
      return OrderStatus.ready;
    }
    return null;
  }


  /// Maneja el tap en el ícono de eliminar.
  /// - Qty == 1: confirmación simple.
  /// - Qty > 1: selector de cuántas unidades quitar.
  void _onDeleteTap(BuildContext context, OrderItem item) async {
    if (item.quantity == 1) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Eliminar ítem'),
          content:
              Text('¿Quitar "${item.productName}" de la orden?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.error),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );
      if (ok == true && context.mounted) controller!.removeItem(item);
      return;
    }

    // Qty > 1: mostrar selector de cantidad
    final result = await showDialog<_RemoveQtyResult>(
      context: context,
      builder: (ctx) => _RemoveQtyDialog(item: item),
    );
    if (result == null || !context.mounted) return;
    if (result.removeAll) {
      controller!.removeItem(item);
    } else {
      controller!.updateItemQty(item, item.quantity - result.qty);
    }
  }

  void _showAddProductSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddProductToOrderSheet(controller: controller!),
    );
  }

  void _showAddItemSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddItemSheet(
        orderId: order.id,
        controller: controller!,
      ),
    );
  }

  Widget _buildModifierLine(ThemeData theme, OrderItemModifier mod) {
    IconData icon;
    Color color;
    switch (mod.type) {
      case ModifierType.removal:
        icon = Icons.remove_circle_outline;
        color = AppColors.error;
        break;
      case ModifierType.addition:
        icon = Icons.add_circle_outline;
        color = AppColors.success;
        break;
      case ModifierType.substitution:
        icon = Icons.swap_horiz;
        color = AppColors.warning;
        break;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              mod.displayText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (mod.hasCost)
            Text(
              mod.priceText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    ThemeData theme,
    String label,
    double amount, {
    Color? color,
    bool isHighlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isHighlight
              ? theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                )
              : theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
        ),
        Text(
          CurrencyFormatter.format(amount.abs()),
          style: isHighlight
              ? theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                )
              : theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
        ),
      ],
    );
  }
}

// ─────────────────────── Progress + bulk action ───────────────────────

/// Card con barra de progreso "X de Y entregados" y botón "Entregar todo
/// lo listo" para que el mesero descargue la bandeja entera de un toque
/// cuando llega a la mesa.
class _DeliveryProgress extends StatelessWidget {
  final Order order;
  final OrderDetailController controller;

  const _DeliveryProgress({
    required this.order,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Forzar dependencia del Rx del controller.
      final _ = controller.order.value;
      final progress = controller.deliveryProgress;
      final delivered = progress.delivered;
      final total = progress.total;
      final pendingReady = order.items
          .where((i) => i.isReady && !i.isDelivered)
          .length;
      final allDelivered = total > 0 && delivered == total;
      final pct = total == 0 ? 0.0 : delivered / total;

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: allDelivered
              ? AppColors.success.withValues(alpha: 0.08)
              : AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: allDelivered
                ? AppColors.success.withValues(alpha: 0.35)
                : AppColors.primary.withValues(alpha: 0.20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  allDelivered
                      ? Icons.task_alt
                      : Icons.delivery_dining_outlined,
                  size: 18,
                  color: allDelivered ? AppColors.success : AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    allDelivered
                        ? 'Todos los items entregados'
                        : 'Entregados $delivered de $total',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: allDelivered
                          ? AppColors.success
                          : AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (pendingReady > 0)
                  FilledButton.icon(
                    onPressed: controller.deliverAllPending,
                    icon: const Icon(Icons.done_all, size: 16),
                    label: Text(
                      pendingReady == total
                          ? 'Entregar todo'
                          : 'Entregar $pendingReady listos',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: Colors.white,
                valueColor: AlwaysStoppedAnimation<Color>(
                  allDelivered ? AppColors.success : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ───────────────────────── Status visuals ─────────────────────────

/// Mapeo declarativo de status → color/icono/label para el badge.
class _ItemStatusVisuals {
  final String label;
  final IconData icon;
  final Color color;

  const _ItemStatusVisuals({
    required this.label,
    required this.icon,
    required this.color,
  });

  factory _ItemStatusVisuals.of(OrderItem item) {
    if (item.isDelivered) {
      return const _ItemStatusVisuals(
        label: 'Entregado',
        icon: Icons.check_circle,
        color: AppColors.success,
      );
    }
    if (item.isReady) {
      return const _ItemStatusVisuals(
        label: 'Listo para entregar',
        icon: Icons.done_all,
        color: AppColors.success,
      );
    }
    switch (item.status) {
      case OrderStatus.preparing:
        return const _ItemStatusVisuals(
          label: 'En cocina',
          icon: Icons.restaurant,
          color: Color(0xFF8E44AD),
        );
      case OrderStatus.cancelled:
        return const _ItemStatusVisuals(
          label: 'Cancelado',
          icon: Icons.cancel_outlined,
          color: AppColors.error,
        );
      case OrderStatus.pendingReview:
      case OrderStatus.pending:
      case OrderStatus.confirmed:
      default:
        return _ItemStatusVisuals(
          label: item.requiresPreparation
              ? 'Por preparar'
              : 'Sin preparación',
          icon: item.requiresPreparation
              ? Icons.schedule
              : Icons.local_bar_outlined,
          color: item.requiresPreparation
              ? AppColors.warning
              : AppColors.info,
        );
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final _ItemStatusVisuals visuals;
  const _StatusBadge({required this.visuals});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: visuals.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: visuals.color.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visuals.icon, size: 12, color: visuals.color),
          const SizedBox(width: 4),
          // Flexible + ellipsis: labels largos ("Sin preparación", "Listo
          // para entregar") no deben desbordar en pantallas chicas.
          Flexible(
            child: Text(
              visuals.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: visuals.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Long-press sheet ─────────────────────────

/// Sheet de acciones por item — escape hatch para "deshacer" un tap
/// equivocado o forzar un estado fuera del avance normal. Las
/// acciones que aparecen se filtran por permisos del rol — un mesero
/// no ve "devolver a cocina"; un cocinero no ve "marcar entregado".
class _ItemActionsSheet extends StatelessWidget {
  final OrderItem item;
  final OrderDetailController controller;
  final _ItemPermissions permissions;

  const _ItemActionsSheet({
    required this.item,
    required this.controller,
    required this.permissions,
  });

  @override
  Widget build(BuildContext context) {
    final actions = <(IconData, String, OrderStatus, Color)>[];

    // Acciones avanzadas — el tap simple ya cubre el caso frecuente
    // (avanzar / deshacer entrega). Acá solo dejamos los edge cases
    // que no se llegan con tap: marcar listo desde pending/confirmed
    // sin pasar por preparing, devolver a cocina, etc.
    if (!item.isReady && !item.isDelivered && permissions.canMarkReady) {
      actions.add((Icons.done_all, 'Marcar como listo',
          OrderStatus.ready, AppColors.success));
    }
    if (item.status != OrderStatus.preparing &&
        !item.isDelivered &&
        permissions.canMarkPreparing) {
      // "Devolver a cocina" es atribución de cocina/bartender (o
      // admin). Mesero no debería poder mandarlo de vuelta.
      actions.add((Icons.restaurant, 'Devolver a cocina',
          OrderStatus.preparing, const Color(0xFF8E44AD)));
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              item.productName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (item.variantName != null && item.variantName!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                item.variantName!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Estado actual: ${_ItemStatusVisuals.of(item).label}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            if (actions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No tenés acciones disponibles para este item '
                  'con tu rol.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            for (final a in actions) ...[
              FilledButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final ok = await controller.updateItemStatus(
                    itemId: item.id,
                    newStatus: a.$3,
                  );
                  // Si el backend rechazó (ej. una excepción de
                  // permisos por race condition entre token y matriz)
                  // el controller ya muestra un snackbar. Acá solo
                  // dejamos un fallback si por algún motivo no se
                  // mostró nada.
                  if (!ok) {
                    AppSnackbar.show(
                      'No se pudo actualizar',
                      'Verificá tu rol o intentá de nuevo.',
                    );
                  }
                },
                icon: Icon(a.$1, size: 18),
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(a.$2),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: a.$4,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Tap target ─────────────────────────

/// Botón circular grande (52×52) — el ÚNICO punto del item que
/// dispara la acción. Tres estados visuales:
///
///   1. Item entregado, rol puede deshacer → círculo verde sólido
///      con check blanco. Tap → confirmación para deshacer.
///   2. Item avanzable por el rol → círculo con borde de color +
///      icono `Icons.radio_button_unchecked`. Tap → avanza al
///      siguiente estado (sin diálogo, instant).
///   3. Item no tocable por este rol (cocina viendo un ready,
///      mesero viendo un pending sin prep, etc.) → círculo gris
///      con icono de estado, NO tappable.
///
/// Mientras hay un update en vuelo para este item, mostramos un
/// `CircularProgressIndicator` adentro del círculo y bloqueamos
/// taps subsiguientes — sin esto el usuario podía tap-tap-tap rápido
/// y dejar múltiples requests en vuelo.
class _DeliveryTapTarget extends StatelessWidget {
  final OrderItem item;
  final OrderStatus? nextStatus;
  final bool canForward;
  final bool canUndoDelivery;
  final bool canShowSheet;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _DeliveryTapTarget({
    required this.item,
    required this.nextStatus,
    required this.canForward,
    required this.canUndoDelivery,
    required this.canShowSheet,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // Si no podemos hacer nada con este item, mostramos un círculo
    // gris pequeño solo de referencia visual (cocina ve check verde
    // si el ítem ya fue entregado por el mesero, etc.).
    if (!canForward && !canUndoDelivery) {
      return _StaticIndicator(item: item);
    }

    final isUndo = !canForward && canUndoDelivery;
    final Color color = isUndo
        ? AppColors.warning
        : (nextStatus == OrderStatus.delivered
            ? AppColors.success
            : AppColors.primary);

    return SizedBox(
      width: 56,
      height: 56,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          onLongPress: canShowSheet ? onLongPress : null,
          child: Center(
            child: _CircleBody(
              item: item,
              color: color,
              isUndo: isUndo,
              isForwardToDelivered:
                  canForward && nextStatus == OrderStatus.delivered,
            ),
          ),
        ),
      ),
    );
  }
}

/// Cuerpo visual del círculo (52×52). Cambia el icono según el
/// destino del tap. Si hay un update en vuelo para este item, muestra
/// un spinner adentro.
class _CircleBody extends StatelessWidget {
  final OrderItem item;
  final Color color;
  final bool isUndo;
  final bool isForwardToDelivered;

  const _CircleBody({
    required this.item,
    required this.color,
    required this.isUndo,
    required this.isForwardToDelivered,
  });

  @override
  Widget build(BuildContext context) {
    final OrderDetailController? ctrl =
        Get.isRegistered<OrderDetailController>()
            ? Get.find<OrderDetailController>()
            : null;
    Widget bodyFor(bool busy) {
      if (busy) {
        return SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.6,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        );
      }
      // Item ya entregado → círculo lleno con check blanco.
      // Item por avanzar → círculo con borde + icono.
      if (item.isDelivered) {
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.30),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 26,
          ),
        );
      }
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2.4),
        ),
        child: Icon(
          isForwardToDelivered
              ? Icons.check_rounded
              : Icons.done_all_rounded,
          color: color,
          size: 24,
        ),
      );
    }

    if (ctrl == null) return bodyFor(false);
    return Obx(() {
      final busy = ctrl.updatingItemIds.contains(item.id);
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: KeyedSubtree(
          key: ValueKey('${item.id}-$busy-${item.status}'),
          child: bodyFor(busy),
        ),
      );
    });
  }
}

/// Indicador no-tappable para items que el rol actual no puede tocar.
/// Mantiene el espacio visual del lado derecho de la lista para que
/// los items queden alineados, pero deja claro que no es interactivo.
class _StaticIndicator extends StatelessWidget {
  final OrderItem item;
  const _StaticIndicator({required this.item});

  @override
  Widget build(BuildContext context) {
    final visuals = _ItemStatusVisuals.of(item);
    final isDone = item.isDelivered ||
        item.status == OrderStatus.completed;
    return SizedBox(
      width: 56,
      height: 56,
      child: Center(
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: visuals.color.withValues(alpha: isDone ? 0.18 : 0.08),
            shape: BoxShape.circle,
            border: Border.all(
              color: visuals.color.withValues(alpha: 0.35),
            ),
          ),
          child: Icon(
            visuals.icon,
            color: visuals.color,
            size: 18,
          ),
        ),
      ),
    );
  }
}

// ───────────────────── Item-level role permissions ─────────────────────

/// Permisos del rol actual para `updateItemStatus`. Mantiene la MISMA
/// matriz que `OrdersService.assertItemStatusTransitionAllowed` en el
/// backend — si el backend cambia, este archivo cambia también, o el
/// usuario verá botones que reciben 403.
///
/// La matriz por rol:
///   - admin/manager → todo
///   - kitchen/bartender → puede `preparing`, `ready` (no entrega)
///   - waiter/cashier → puede `ready`, `delivered` (no manda a cocina)
///   - delivery → puede `delivered` SOLO en órdenes `order_type=delivery`
///   - cualquier otro / sin rol → nada
class _ItemPermissions {
  final bool canMarkReady;
  final bool canDeliver;
  final bool canMarkPreparing;

  const _ItemPermissions({
    required this.canMarkReady,
    required this.canDeliver,
    required this.canMarkPreparing,
  });

  factory _ItemPermissions.fromRole(String? roleCode, Order order) {
    if (roleCode == null) {
      return const _ItemPermissions(
        canMarkReady: false,
        canDeliver: false,
        canMarkPreparing: false,
      );
    }
    switch (roleCode) {
      case 'admin':
      case 'manager':
        return const _ItemPermissions(
          canMarkReady: true,
          canDeliver: true,
          canMarkPreparing: true,
        );
      case 'kitchen':
      case 'bartender':
        return const _ItemPermissions(
          canMarkReady: true,
          canDeliver: false,
          canMarkPreparing: true,
        );
      case 'waiter':
      case 'cashier':
        return const _ItemPermissions(
          canMarkReady: true,
          canDeliver: true,
          canMarkPreparing: false,
        );
      case 'delivery':
        // Repartidor solo puede marcar entregado, y solo en órdenes
        // que efectivamente son delivery — espejo de la regla del
        // backend.
        final isDelivery = order.orderType == OrderType.delivery;
        return _ItemPermissions(
          canMarkReady: false,
          canDeliver: isDelivery,
          canMarkPreparing: false,
        );
      default:
        return const _ItemPermissions(
          canMarkReady: false,
          canDeliver: false,
          canMarkPreparing: false,
        );
    }
  }

  bool get hasAnyTransition =>
      canMarkReady || canDeliver || canMarkPreparing;
}

// ───────────────────── Undo delivery confirmation ─────────────────────

/// Dialog de confirmación para deshacer la entrega de un item. Diseño:
/// header naranja con icono `undo`, nombre del item destacado, texto
/// claro de qué pasa, y dos botones — Cancelar (neutro) / Deshacer
/// (naranja). Compacto, sin scrim del AlertDialog estándar.
class _UndoDeliveryDialog extends StatelessWidget {
  final OrderItem item;
  const _UndoDeliveryDialog({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.undo_rounded,
                    color: AppColors.warning,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '¿Deshacer entrega?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${item.quantity}x',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (item.variantName != null &&
                            item.variantName!.isNotEmpty)
                          Text(
                            item.variantName!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'El item volverá a estado "Listo" y dejará de contar como '
              'entregado. Usalo solo si lo tocaste por error o si el '
              'cliente devolvió el plato.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: const Text(
                      'Sí, deshacer',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
    );
  }
}

// ─────────────────────── Add item button ───────────────────────

class _AddItemButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final Color color;

  const _AddItemButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── Add item sheet ───────────────────────

class _AddItemSheet extends StatefulWidget {
  final String orderId;
  final OrderDetailController controller;

  const _AddItemSheet({required this.orderId, required this.controller});

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  int _qty = 1;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double get _parsedPrice {
    final raw = _priceCtrl.text.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(raw) ?? 0;
  }

  bool get _canSubmit =>
      _nameCtrl.text.trim().isNotEmpty && _parsedPrice > 0 && _qty >= 1;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _saving = true);
    final ok = await widget.controller.addItem(
      productName: _nameCtrl.text.trim(),
      unitPrice: _parsedPrice,
      quantity: _qty,
      specialInstructions: _noteCtrl.text.trim().isEmpty
          ? null
          : _noteCtrl.text.trim(),
    );
    setState(() => _saving = false);
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final kb = mq.viewInsets.bottom;
    final safeBottom = mq.viewPadding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: mq.size.height * 0.88 - safeBottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, safeBottom + 20 + kb),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.add_circle_outline, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Agregar adicional',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Name
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre del adicional *',
                hintText: 'Ej: Pollo extra',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label_outline),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Price
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Precio *',
                      hintText: '3.000',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                // Qty stepper
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cantidad',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                      const SizedBox(height: 4),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: theme.colorScheme.outline),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: _qty > 1
                                  ? () => setState(() => _qty--)
                                  : null,
                            ),
                            Text('$_qty',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: () => setState(() => _qty++),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Note
            TextField(
              controller: _noteCtrl,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                hintText: 'Ej: Al gusto del cliente',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.sticky_note_2_outlined),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _canSubmit && !_saving ? _submit : null,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Agregar'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── Diálogo eliminar por cantidad ───────────────────────

class _RemoveQtyResult {
  final int qty;
  final bool removeAll;
  const _RemoveQtyResult({required this.qty, required this.removeAll});
}

/// Dialog para seleccionar cuántas unidades de un ítem eliminar.
/// Aparece solo cuando el ítem tiene qty > 1.
class _RemoveQtyDialog extends StatefulWidget {
  final OrderItem item;
  const _RemoveQtyDialog({required this.item});

  @override
  State<_RemoveQtyDialog> createState() => _RemoveQtyDialogState();
}

class _RemoveQtyDialogState extends State<_RemoveQtyDialog> {
  late int _toRemove = 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = widget.item.quantity;
    final removeAll = _toRemove >= max;

    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.remove_shopping_cart_outlined,
                      color: AppColors.error, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Quitar unidades',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text('${max}x',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: theme.colorScheme.onPrimaryContainer,
                        )),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.item.productName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('¿Cuántas unidades quitar?',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            // Stepper de cantidad a quitar
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  color: AppColors.error,
                  iconSize: 32,
                  onPressed: _toRemove > 1
                      ? () => setState(() => _toRemove--)
                      : null,
                ),
                Container(
                  width: 64,
                  alignment: Alignment.center,
                  child: Text('$_toRemove',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.primary,
                  iconSize: 32,
                  onPressed: _toRemove < max
                      ? () => setState(() => _toRemove++)
                      : null,
                ),
              ],
            ),
            // Preview del resultado
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: removeAll
                    ? AppColors.error.withValues(alpha: 0.07)
                    : AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                removeAll
                    ? 'Se eliminará el ítem completo de la orden'
                    : 'Quedarán ${max - _toRemove} unidad(es) en la orden',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: removeAll ? AppColors.error : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(
                      context,
                      _RemoveQtyResult(qty: _toRemove, removeAll: removeAll),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(removeAll ? 'Eliminar todo' : 'Quitar $_toRemove'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── Agregar producto del catálogo ───────────────────────

class _AddProductToOrderSheet extends StatefulWidget {
  final OrderDetailController controller;
  const _AddProductToOrderSheet({required this.controller});

  @override
  State<_AddProductToOrderSheet> createState() =>
      _AddProductToOrderSheetState();
}

class _AddProductToOrderSheetState extends State<_AddProductToOrderSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<ProductsController>()) {
      ProductsBinding().dependencies();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Product> get _filtered {
    if (!Get.isRegistered<ProductsController>()) return [];
    final all = Get.find<ProductsController>().products;
    if (_query.isEmpty) return all.toList();
    final q = _query.toLowerCase();
    return all.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  void _onProductTap(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProductPickerDetail(
        product: product,
        // unitPrice ya viene ajustado desde el sheet (base ± ajuste)
        onConfirm: (variant, qty, unitPrice, note) async {
          final ok = await widget.controller.addItem(
            productId: product.id,
            variantId: variant?.id,
            unitPrice: unitPrice,
            quantity: qty,
            specialInstructions: note.isEmpty ? null : note,
          );
          if (ok && ctx.mounted) {
            Navigator.of(ctx).pop();
            if (mounted) Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final safeBottom = mq.viewPadding.bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: mq.size.height * 0.9 - safeBottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Agregar producto',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar producto…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: Builder(builder: (_) {
              final items = _filtered;
              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _query.isEmpty
                          ? 'Sin productos registrados'
                          : 'Sin resultados para "$_query"',
                      style: const TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = items[i];
                  return ListTile(
                    dense: true,
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.fastfood_outlined,
                          size: 18, color: AppColors.primary),
                    ),
                    title: Text(p.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(CurrencyFormatter.format(p.basePrice),
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => _onProductTap(p),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _ProductPickerDetail extends StatefulWidget {
  final Product product;
  // unitPrice ya viene calculado (base ± ajuste manual)
  final Future<void> Function(
    ProductVariant? variant,
    int qty,
    double unitPrice,
    String note,
  ) onConfirm;

  const _ProductPickerDetail({required this.product, required this.onConfirm});

  @override
  State<_ProductPickerDetail> createState() => _ProductPickerDetailState();
}

class _ProductPickerDetailState extends State<_ProductPickerDetail> {
  ProductVariant? _variant;
  int _qty = 1;
  final _noteCtrl = TextEditingController();
  final _adjustAmountCtrl = TextEditingController();
  final _adjustReasonCtrl = TextEditingController();
  bool _saving = false;
  // -1 = descuento, +1 = adicional
  int _adjustSign = -1;
  bool _adjustOpen = false;

  @override
  void initState() {
    super.initState();
    if (widget.product.variants.length == 1) {
      _variant = widget.product.variants.first;
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _adjustAmountCtrl.dispose();
    _adjustReasonCtrl.dispose();
    super.dispose();
  }

  double get _basePrice => _variant != null
      ? widget.product.basePrice + _variant!.priceModifier
      : widget.product.basePrice;

  double get _adjustAmount {
    if (!_adjustOpen) return 0;
    final raw = NumberFormatHelper.parseFormattedInt(
            _adjustAmountCtrl.text) ??
        0;
    return raw.toDouble() * _adjustSign;
  }

  double get _unitPrice => (_basePrice + _adjustAmount).clamp(0, double.infinity);

  double get _totalPrice => _unitPrice * _qty;

  String _buildNote() {
    final parts = <String>[];
    if (_adjustOpen && _adjustAmount != 0) {
      final sign = _adjustAmount < 0 ? '-' : '+';
      final label = _adjustReasonCtrl.text.trim();
      final amount = CurrencyFormatter.format(_adjustAmount.abs());
      parts.add(label.isNotEmpty
          ? '$label ($sign$amount)'
          : '${_adjustSign < 0 ? "Descuento" : "Adicional"} ($sign$amount)');
    }
    final note = _noteCtrl.text.trim();
    if (note.isNotEmpty) parts.add(note);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final kb = mq.viewInsets.bottom;
    final safeBottom = mq.viewPadding.bottom;
    final variants = widget.product.variants;

    return Container(
      constraints: BoxConstraints(
        maxHeight: mq.size.height * 0.92 - safeBottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.product.name,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Contenido scrollable ─────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, safeBottom + 8 + kb),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Variantes ────────────────────────────────────────
                  if (variants.isNotEmpty) ...[
                    Text('Variante',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8, runSpacing: 6,
                      children: variants.map((v) {
                        final sel = _variant?.id == v.id;
                        return ChoiceChip(
                          label: Text(
                            '${v.name} · ${CurrencyFormatter.format(widget.product.basePrice + v.priceModifier)}',
                          ),
                          selected: sel,
                          onSelected: (_) => setState(() => _variant = v),
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.15),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Cantidad ─────────────────────────────────────────
                  Row(
                    children: [
                      Text('Cantidad',
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: AppColors.textSecondary)),
                      const Spacer(),
                      _QtySelector(
                        qty: _qty,
                        onDecrement: _qty > 1
                            ? () => setState(() => _qty--)
                            : null,
                        onIncrement: () => setState(() => _qty++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Ajuste de precio ──────────────────────────────────
                  _AjustePrecioSection(
                    open: _adjustOpen,
                    sign: _adjustSign,
                    amountCtrl: _adjustAmountCtrl,
                    reasonCtrl: _adjustReasonCtrl,
                    onToggleOpen: () =>
                        setState(() => _adjustOpen = !_adjustOpen),
                    onChangeSign: (s) => setState(() => _adjustSign = s),
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 16),

                  // ── Nota ─────────────────────────────────────────────
                  TextField(
                    controller: _noteCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Nota adicional (opcional)',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.sticky_note_2_outlined),
                      isDense: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      filled: true,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Footer fijo ──────────────────────────────────────────────
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, safeBottom + 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Total',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: AppColors.textSecondary)),
                      Text(
                        CurrencyFormatter.format(_totalPrice),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      if (_adjustOpen && _adjustAmount != 0)
                        Text(
                          '${CurrencyFormatter.format(_basePrice)} ${_adjustAmount < 0 ? "-" : "+"} ${CurrencyFormatter.format(_adjustAmount.abs())}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _adjustAmount < 0
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  icon: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add, size: 18),
                  label: const Text('Agregar'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(120, 48)),
                  onPressed: _saving
                      ? null
                      : () async {
                          if (variants.isNotEmpty && _variant == null) {
                            AppSnackbar.show(
                                'Falta variante', 'Selecciona una variante');
                            return;
                          }
                          setState(() => _saving = true);
                          await widget.onConfirm(
                            _variant,
                            _qty,
                            _unitPrice,
                            _buildNote(),
                          );
                          if (mounted) setState(() => _saving = false);
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stepper de cantidad ───────────────────────────────────────────────────────
class _QtySelector extends StatelessWidget {
  final int qty;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;

  const _QtySelector({
    required this.qty,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            onPressed: onDecrement,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: onIncrement,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          ),
        ],
      ),
    );
  }
}

// ── Sección de ajuste de precio ───────────────────────────────────────────────
class _AjustePrecioSection extends StatelessWidget {
  final bool open;
  final int sign; // -1 o +1
  final TextEditingController amountCtrl;
  final TextEditingController reasonCtrl;
  final VoidCallback onToggleOpen;
  final ValueChanged<int> onChangeSign;
  final VoidCallback onChanged;

  const _AjustePrecioSection({
    required this.open,
    required this.sign,
    required this.amountCtrl,
    required this.reasonCtrl,
    required this.onToggleOpen,
    required this.onChangeSign,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: open
              ? (sign < 0
                  ? AppColors.success.withValues(alpha: 0.6)
                  : AppColors.primary.withValues(alpha: 0.6))
              : theme.colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(12),
        color: open
            ? (sign < 0
                ? AppColors.success.withValues(alpha: 0.05)
                : AppColors.primary.withValues(alpha: 0.05))
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      child: Column(
        children: [
          // Fila toggle
          InkWell(
            onTap: onToggleOpen,
            borderRadius: open
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: open
                        ? (sign < 0 ? AppColors.success : AppColors.primary)
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ajustar precio',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: open
                            ? (sign < 0 ? AppColors.success : AppColors.primary)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    open ? 'Quitar ajuste' : 'Agregar ajuste',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    open
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // Panel expandido
          if (open) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Toggle descuento / adicional
                  Row(
                    children: [
                      Expanded(
                        child: _SignChip(
                          label: 'Descuento (−)',
                          selected: sign < 0,
                          color: AppColors.success,
                          onTap: () => onChangeSign(-1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SignChip(
                          label: 'Adicional (+)',
                          selected: sign > 0,
                          color: AppColors.primary,
                          onTap: () => onChangeSign(1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Motivo + monto en la misma fila
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: reasonCtrl,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => onChanged(),
                          decoration: const InputDecoration(
                            labelText: 'Motivo',
                            hintText: 'Ej: Sin gaseosa',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => onChanged(),
                          decoration: InputDecoration(
                            labelText: 'Valor',
                            hintText: '1.000',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            prefixText:
                                sign < 0 ? '−\$' : '+\$',
                            prefixStyle: TextStyle(
                              color: sign < 0
                                  ? AppColors.success
                                  : AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SignChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SignChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(
            color: selected ? color : Theme.of(context).colorScheme.outline,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
