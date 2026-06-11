import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../data/models/order_model.dart';
import '../controllers/pending_review_controller.dart';

/// Pantalla "Pendientes de aprobación".
///
/// Diseñada para que el mesero la abra en su celular y pueda decidir
/// rapidísimo aprobar/rechazar cada pedido entrante. Layout pensado
/// para uso con una sola mano: acciones grandes, info crítica arriba,
/// detalles abajo.
class PendingReviewPage extends GetView<PendingReviewController> {
  const PendingReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Obx(() => Text(
              controller.orders.isEmpty
                  ? 'Pendientes de aprobación'
                  : 'Pendientes (${controller.count.value})',
            )),
        actions: [
          Obx(() => controller.loading.value
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : IconButton(
                  tooltip: 'Refrescar',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => controller.fetch(),
                )),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.loading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.error.value != null && controller.orders.isEmpty) {
            return _ErrorState(
              message: controller.error.value!,
              onRetry: () => controller.fetch(initial: true),
            );
          }
          if (controller.orders.isEmpty) {
            return const _EmptyState();
          }
          return RefreshIndicator(
            onRefresh: () => controller.fetch(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              itemCount: controller.orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final order = controller.orders[i];
                return _PendingOrderCard(
                  order: order,
                  controller: controller,
                );
              },
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Card de una orden pendiente
// ---------------------------------------------------------------------
class _PendingOrderCard extends StatelessWidget {
  final OrderModel order;
  final PendingReviewController controller;

  const _PendingOrderCard({required this.order, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isProcessing = controller.processingIds.contains(order.id);
      return Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        elevation: 1.5,
        shadowColor: Colors.black12,
        child: InkWell(
          // Tap en el card (excepto botones) → abrir detalle completo
          // de la orden para ver modificadores, notas largas, etc.
          // Coherencia con el resto de la app donde la lista lleva al
          // detalle. Los botones internos tienen su propio onPressed
          // que captura el tap antes (no bubble up).
          borderRadius: BorderRadius.circular(16),
          onTap: () => Get.toNamed('/orders/${order.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CardHeader(order: order),
                const SizedBox(height: 10),
                _CustomerRow(order: order),
                const SizedBox(height: 10),
                _ItemsList(order: order),
                const Divider(height: 22),
                _TotalRow(order: order),
                const SizedBox(height: 14),
                _Actions(
                  order: order,
                  isProcessing: isProcessing,
                  controller: controller,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _CardHeader extends StatelessWidget {
  final OrderModel order;
  const _CardHeader({required this.order});

  @override
  Widget build(BuildContext context) {
    final waitedMinutes = _minutesSince(order.createdAt);
    final isUrgent = waitedMinutes >= 5;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.orderNumber,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _destinationLabel(order),
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: isUrgent
                ? AppColors.error.withValues(alpha: 0.12)
                : Colors.amber.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule,
                size: 14,
                color: isUrgent ? AppColors.error : Colors.amber.shade800,
              ),
              const SizedBox(width: 4),
              Text(
                waitedMinutes == 0 ? 'ahora' : '$waitedMinutes min',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isUrgent ? AppColors.error : Colors.amber.shade900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static int _minutesSince(String? iso) {
    if (iso == null || iso.isEmpty) return 0;
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 0;
    return DateTime.now().difference(dt).inMinutes;
  }

  static String _destinationLabel(OrderModel order) {
    // Preferimos siempre `table_label` (snapshot legible al crear
    // la orden, ej. "Mesa 1 · Areas verdes"). Fallback al name legacy.
    // No mostramos `tableElementId` (UUID) bajo ninguna circunstancia.
    if (order.tableLabel != null && order.tableLabel!.trim().isNotEmpty) {
      return order.tableLabel!;
    }
    if (order.tableName != null && order.tableName!.trim().isNotEmpty) {
      return 'Mesa ${order.tableName}';
    }
    return order.orderType == 'takeaway' ? 'Pickup' : 'Sin mesa asignada';
  }
}

class _CustomerRow extends StatelessWidget {
  final OrderModel order;
  const _CustomerRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final name = order.customerName ?? 'Cliente sin nombre';
    final phone = order.customerPhone ?? '';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (phone.isNotEmpty) ...[
            const Icon(Icons.phone, size: 16),
            const SizedBox(width: 4),
            Text(
              phone,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemsList extends StatelessWidget {
  final OrderModel order;
  const _ItemsList({required this.order});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: order.items.map((it) {
        final name = it.productName;
        final qty = it.quantity;
        final notes = it.specialInstructions;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '${qty}x', // braces obligatorias: `x` haría parte del id
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (notes != null && notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          notes,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final OrderModel order;
  const _TotalRow({required this.order});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Total',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(
          CurrencyFormatter.format(order.totalAmount),
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  final OrderModel order;
  final bool isProcessing;
  final PendingReviewController controller;

  const _Actions({
    required this.order,
    required this.isProcessing,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isProcessing
                ? null
                : () => _confirmReject(context, order, controller),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Rechazar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: isProcessing
                ? null
                : () => controller.approve(
                      order.id,
                      toConfirmed: true,
                      // Auto-imprimir vía PrintingOrchestrator. Si hay
                      // impresora default con auto_print, sale sola
                      // sin diálogo (red TCP) o pide confirmación
                      // (sistema). Si no hay default configurada,
                      // no-op silencioso.
                      printKitchen: true,
                      destinationLabel: order.tableLabel ??
                          (order.tableName != null
                              ? 'Mesa ${order.tableName}'
                              : null),
                    ),
            icon: isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check, size: 18),
            label: const Text('Aprobar y enviar a cocina'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmReject(
    BuildContext context,
    OrderModel order,
    PendingReviewController controller,
  ) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Rechazar ${order.orderNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Indicá brevemente por qué rechazás el pedido. Esta nota queda en el historial.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              autofocus: true,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: 'Ej: mesa vacía, cliente se fue, pedido erróneo',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () =>
                Navigator.of(dialogCtx).pop(reasonController.text.trim()),
            child: const Text('Rechazar pedido'),
          ),
        ],
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      await controller.reject(order.id, reason);
    }
  }
}

// ---------------------------------------------------------------------
// Estados auxiliares
// ---------------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: 48,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '¡Todo al día!',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
          ),
          const SizedBox(height: 6),
          Text(
            'No hay pedidos esperando aprobación.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber, size: 56, color: AppColors.error),
            const SizedBox(height: 14),
            const Text(
              'No pudimos cargar los pedidos',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
