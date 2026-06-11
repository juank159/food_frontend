import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/app_gradient_header.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../orders/domain/entities/order.dart';
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

  /// Tickets visibles para cocina: confirmed + preparing. Ordenados por
  /// más antiguos primero (FIFO — primero entra, primero sale).
  List<Order> _kitchenTickets(OrdersController c) {
    final list = c.orders.where((o) {
      return o.status == OrderStatus.confirmed ||
          o.status == OrderStatus.preparing;
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
      final waiting = tickets
          .where((o) => o.status == OrderStatus.confirmed)
          .length;
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
                  for (final item in order.items) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (item.specialInstructions != null &&
                        item.specialInstructions!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(36, 2, 0, 0),
                        child: Text(
                          '➜ ${item.specialInstructions}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
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

/// Helper para mostrar el horario de creación en cards detallados —
/// no se usa en el grid principal pero queda disponible.
String _fmtTime(DateTime t) => DateFormat('HH:mm').format(t);
