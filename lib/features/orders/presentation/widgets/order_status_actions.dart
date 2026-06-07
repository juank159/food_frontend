import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/widgets/modern_card.dart';
import '../controllers/order_detail_controller.dart';

/// Order Status Actions
/// Widget para acciones de cambio de estado de la orden
class OrderStatusActions extends StatelessWidget {
  final OrderDetailController controller;

  const OrderStatusActions({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final availableTransitions = controller.getAvailableStatusTransitions();

      if (availableTransitions.isEmpty) {
        return const SizedBox.shrink();
      }

      return ModernCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.swap_horiz,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Cambiar Estado',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: availableTransitions.map((status) {
                  return _buildStatusButton(context, status);
                }).toList(),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildStatusButton(BuildContext context, OrderStatus status) {
    final theme = Theme.of(context);
    final isCancelling = status == OrderStatus.cancelled;

    return Obx(() {
      final isUpdating = controller.isUpdatingStatus.value;

      return FilledButton.icon(
        onPressed: isUpdating
            ? null
            : () => _confirmStatusChange(context, status),
        style: FilledButton.styleFrom(
          backgroundColor:
              isCancelling ? theme.colorScheme.error : _getStatusColor(status),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        icon: Icon(_getStatusIcon(status), size: 20),
        label: Text(status.displayName),
      );
    });
  }

  void _confirmStatusChange(BuildContext context, OrderStatus newStatus) {
    final isCancelling = newStatus == OrderStatus.cancelled;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isCancelling ? Icons.warning : Icons.info,
              color: isCancelling ? theme.colorScheme.error : null,
            ),
            const SizedBox(width: 12),
            Text(
              isCancelling ? 'Cancelar Orden' : 'Cambiar Estado',
            ),
          ],
        ),
        content: Text(
          isCancelling
              ? '¿Estás seguro de cancelar esta orden? Esta acción no se puede deshacer.'
              : '¿Cambiar el estado de la orden a "${newStatus.displayName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              controller.updateOrderStatus(newStatus);
            },
            style: FilledButton.styleFrom(
              backgroundColor: isCancelling ? theme.colorScheme.error : null,
            ),
            child: const Text('Sí, Continuar'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.purple;
      case OrderStatus.ready:
        return Colors.green;
      case OrderStatus.delivered:
        return Colors.teal;
      case OrderStatus.completed:
        return Colors.green.shade700;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.pending;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline;
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.ready:
        return Icons.done_all;
      case OrderStatus.delivered:
        return Icons.delivery_dining;
      case OrderStatus.completed:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
    }
  }
}
