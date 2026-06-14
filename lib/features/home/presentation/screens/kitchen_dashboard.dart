import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/app_gradient_header.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/domain/entities/order_item.dart';
import '../../../orders/domain/usecases/update_order_item_status_usecase.dart';
import '../../../orders/presentation/controllers/orders_controller.dart';

/// **Kitchen Display System (KDS)** — pantalla full-screen para el rol
/// `kitchen` (y `bartender`).
///
/// Diseñada para uso en cocina: tabletas montadas, mucho contraste,
/// targets táctiles grandes, sin distracciones de gestión.
///
/// **Flujo:**
///   1. La cocina ve todas las órdenes en estado `confirmed` o
///      `preparing` como cards grandes con los items + notas.
///   2. Un tap en el botón "Empezar" mueve de `confirmed` → `preparing`.
///   3. Un tap en "Marcar lista" mueve de `preparing` → `ready` y la
///      card desaparece (vuelve al mesero para servir).
///
/// **Diseño:**
///   - Header gradient con conteo de tickets pendientes.
///   - Grid responsivo: 1 col en mobile, 2 col en tablet, 3+ en desktop.
///   - Cada ticket muestra: # orden, mesa/destino, tiempo desde que se
///     confirmó (rojo si > 15 min), items con cantidad y notas.
class KitchenDashboard extends StatelessWidget {
  const KitchenDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<OrdersController>();
    final authController = Get.find<AuthController>();

    // Forzamos a que el listado muestre solo órdenes activas — la
    // cocina no necesita ver completas/canceladas.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.showOnlyActive.value) {
        controller.showOnlyActive.value = true;
        controller.loadActiveOrders();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(authController, controller),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value && !controller.hasOrders) {
                  return const Center(child: CircularProgressIndicator());
                }
                final tickets = _kitchenTickets(controller);
                if (tickets.isEmpty) return _buildEmpty();
                return RefreshIndicator(
                  onRefresh: controller.refreshOrders,
                  child: _buildGrid(context, tickets, controller),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  /// Tickets visibles para cocina: confirmed + preparing, MÁS órdenes
  /// `pending` que contienen al menos un item que requiere preparación.
  ///
  /// Por qué incluir pending: con el flujo nuevo el waiter marca items
  /// como entregados directamente desde el detalle (skip de `ready`),
  /// así que la orden puede quedar en `pending` aunque tenga items en
  /// cocina. Sin esta línea, esos tickets nunca aparecían en el KDS y
  /// la cocina trabajaba "a ciegas" hasta que alguien confirmara la
  /// orden manualmente.
  ///
  /// Items NO prep (bebidas embotelladas, snacks empacados) NO cuentan
  /// — si una orden es solo "una coca-cola" no debería entrar al KDS.
  ///
  /// Ordenados FIFO (primero entra, primero sale).
  List<Order> _kitchenTickets(OrdersController c) {
    final list = c.orders.where((o) {
      if (o.status == OrderStatus.confirmed ||
          o.status == OrderStatus.preparing) {
        return true;
      }
      if (o.status == OrderStatus.pending) {
        return o.items.any((i) => i.requiresPreparation);
      }
      return false;
    }).toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  Widget _buildHeader(
    AuthController authController,
    OrdersController controller,
  ) {
    final name = authController.currentUser?.firstName ?? 'Cocina';
    return Obx(() {
      final tickets = _kitchenTickets(controller);
      final preparing = tickets
          .where((o) => o.status == OrderStatus.preparing)
          .length;
      // "Esperando" cubre tanto las órdenes en `confirmed` como las
      // `pending` con items que requieren prep (ahora pueden coexistir
      // — ver `_kitchenTickets`).
      final waiting = tickets.length - preparing;
      return AppGradientHeader(
        title: 'Cocina · $name',
        subtitle: '$waiting esperando · $preparing en preparación',
        trailing: GestureDetector(
          onTap: controller.refreshOrders,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.refresh, color: Colors.white, size: 22),
          ),
        ),
      );
    });
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.local_dining_outlined,
              size: 44,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sin tickets en cola',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Cuando entren órdenes confirmadas\naparecerán acá automáticamente.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    List<Order> tickets,
    OrdersController controller,
  ) {
    final width = MediaQuery.of(context).size.width;
    final columns = width >= 1200
        ? 4
        : width >= 800
            ? 3
            : width >= 560
                ? 2
                : 1;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: tickets.length,
      itemBuilder: (_, i) =>
          _TicketCard(order: tickets[i], controller: controller),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Order order;
  final OrdersController controller;

  const _TicketCard({required this.order, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isPreparing = order.status == OrderStatus.preparing;
    final accent = isPreparing ? AppColors.warning : AppColors.primary;
    final minutes = DateTime.now().difference(order.createdAt).inMinutes;
    final isLate = minutes >= 15;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLate
              ? AppColors.error
              : accent.withValues(alpha: 0.4),
          width: isLate ? 2 : 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del ticket.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.displayTableLabel,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '#${order.orderNumber}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLate
                        ? AppColors.error
                        : Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${minutes}m',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Body — items.
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Solo items que VAN a cocina/barra. La botella de
                  // agua y la gaseosa no se cuentan acá — la cocina
                  // no las prepara y el mesero las entrega directo.
                  for (final item in order.items.where(
                    (i) => i.requiresPreparation,
                  )) ...[
                    _ItemRow(
                      item: item,
                      orderId: order.id,
                      accent: accent,
                      controller: controller,
                    ),
                  ],
                  if (order.specialInstructions != null &&
                      order.specialInstructions!.isNotEmpty) ...[
                    const Divider(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '⚠ ${order.specialInstructions}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Footer — acción según estado.
          Padding(
            padding: const EdgeInsets.all(8),
            child: _ActionButton(
              order: order,
              controller: controller,
              isPreparing: isPreparing,
              accent: accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de un item dentro de la card del ticket. Tiene un check a la
/// izquierda — al tocarlo el cocinero marca ese item como `ready`. El
/// backend auto-avanza la orden cuando TODOS los items con preparación
/// llegan a `ready`. Items ya listos se ven tachados y verdes.
class _ItemRow extends StatelessWidget {
  final OrderItem item;
  final String orderId;
  final Color accent;
  final OrdersController controller;

  const _ItemRow({
    required this.item,
    required this.orderId,
    required this.accent,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final ready = item.isReady;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: ready
                ? null
                : () async {
                    HapticFeedback.mediumImpact();
                    // Llamamos al use case directo en vez de pasar por
                    // un método del controller — el OrdersController no
                    // tiene optimistic update y duplicaba la versión
                    // del OrderDetailController. Acá la cocina no
                    // necesita optimistic (un tap = un cambio simple),
                    // así que el use case + applyOrderUpdate alcanza.
                    final result = await sl<UpdateOrderItemStatusUseCase>()(
                      orderId: orderId,
                      itemId: item.id,
                      status: OrderStatus.ready,
                    );
                    result.fold(
                      (failure) => AppSnackbar.show(
                        'No se pudo marcar el item',
                        failure.message,
                      ),
                      controller.applyOrderUpdate,
                    );
                  },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: ready
                        ? AppColors.success
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: ready
                          ? AppColors.success
                          : AppColors.border,
                      width: 1.6,
                    ),
                  ),
                  child: ready
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 18)
                      : null,
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${item.quantity}×',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.productName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ready
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      height: 1.2,
                      decoration: ready
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (item.specialInstructions != null &&
              item.specialInstructions!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(46, 2, 0, 0),
              child: Text(
                '➜ ${item.specialInstructions}',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: ready
                      ? AppColors.textHint
                      : AppColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Order order;
  final OrdersController controller;
  final bool isPreparing;
  final Color accent;

  const _ActionButton({
    required this.order,
    required this.controller,
    required this.isPreparing,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (isPreparing) {
      return FilledButton.icon(
        onPressed: () => _move(OrderStatus.ready),
        icon: const Icon(Icons.check_circle),
        label: const Text(
          'Marcar lista',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: () => _move(OrderStatus.preparing),
      icon: const Icon(Icons.play_arrow),
      label: const Text(
        'Empezar',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _move(OrderStatus next) async {
    HapticFeedback.mediumImpact();
    await controller.updateOrderStatus(order.id, next);
  }
}

