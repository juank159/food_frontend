import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';

/// Card de un ticket dentro de una cuenta abierta.
///
/// Recibe el JSON crudo del backend (Order serializado) en vez de la
/// entity completa para no depender de toda la conversión del feature
/// orders en este feature. Solo extraemos los campos visibles.
class TabTicketCard extends StatelessWidget {
  final Map<String, dynamic> rawOrder;

  const TabTicketCard({super.key, required this.rawOrder});

  double _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final id = rawOrder['id'] as String? ?? '';
    final orderNumber = rawOrder['order_number'] as String? ?? '---';
    final orderType = rawOrder['order_type'] as String? ?? '';
    final status = rawOrder['status'] as String? ?? 'pending';
    final totalAmount = _parseNum(rawOrder['total_amount']);
    final totalItems = (rawOrder['total_items'] as num?)?.toInt() ?? 0;
    final createdAt = rawOrder['created_at'] as String?;

    final payments = rawOrder['payments'] as List<dynamic>? ?? const [];
    final paidAmount = payments
        .whereType<Map<String, dynamic>>()
        .where((p) => p['status'] == 'completed')
        .fold<double>(0, (sum, p) => sum + _parseNum(p['amount']));
    final balance = totalAmount - paidAmount;
    final isFullyPaid = balance <= 0.01;

    final typeMeta = _typeMeta(orderType);
    final statusColor = _statusColor(status);

    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => Get.toNamed(
          AppRoutes.orderDetail.replaceAll(':id', id),
        ),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: typeMeta.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(typeMeta.icon, size: 18, color: typeMeta.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            orderNumber,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _statusLabel(status),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        typeMeta.label,
                        '$totalItems items',
                        if (createdAt != null)
                          DateFormat('HH:mm')
                              .format(DateTime.parse(createdAt)),
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    CurrencyFormatter.format(totalAmount),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (isFullyPaid)
                    const Text(
                      'Pagado',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                      ),
                    )
                  else
                    Text(
                      'Debe ${CurrencyFormatter.format(balance)}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.error,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  _TypeMeta _typeMeta(String type) {
    switch (type) {
      case 'takeaway':
        return _TypeMeta(
          icon: Icons.takeout_dining_outlined,
          label: 'Para llevar',
          color: AppColors.warning,
        );
      case 'delivery':
        return _TypeMeta(
          icon: Icons.delivery_dining_outlined,
          label: 'Domicilio',
          color: AppColors.info,
        );
      case 'dine_in':
      default:
        return _TypeMeta(
          icon: Icons.restaurant_outlined,
          label: 'En el local',
          color: AppColors.primary,
        );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.textSecondary;
      case 'cancelled':
        return AppColors.error;
      case 'ready':
        return AppColors.success;
      case 'preparing':
        return AppColors.warning;
      case 'pending':
      default:
        return AppColors.info;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'PENDIENTE';
      case 'preparing':
        return 'EN PREPARACIÓN';
      case 'ready':
        return 'LISTO';
      case 'delivered':
        return 'ENTREGADO';
      case 'completed':
        return 'COMPLETADO';
      case 'cancelled':
        return 'CANCELADO';
      default:
        return status.toUpperCase();
    }
  }
}

class _TypeMeta {
  final IconData icon;
  final String label;
  final Color color;
  _TypeMeta({required this.icon, required this.label, required this.color});
}
