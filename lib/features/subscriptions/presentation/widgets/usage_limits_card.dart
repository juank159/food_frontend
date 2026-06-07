import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../controllers/subscription_controller.dart';

class UsageLimitsCard extends GetView<SubscriptionController> {
  const UsageLimitsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final usage = controller.usage.value;
      if (usage == null) return const SizedBox.shrink();

      final limits = usage.limits;
      if (limits.isEmpty) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.dashboard, color: AppColors.primary, size: 24),
                SizedBox(width: 12),
                Text(
                  'Uso y Límites',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...limits.entries.map((entry) {
              final limit = entry.value is int ? entry.value as int : -1;
              final isUnlimited = limit == -1;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _getLimitLabel(entry.key),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          isUnlimited
                              ? 'Ilimitado'
                              : '${_getUsageValue(entry.key)} / $limit',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isUnlimited
                                ? AppColors.success
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    if (!isUnlimited) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _calculateUsagePercentage(
                          entry.key,
                          limit,
                        ),
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getProgressColor(
                            _calculateUsagePercentage(entry.key, limit),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      );
    });
  }

  String _getLimitLabel(String key) {
    const labels = {
      'max_users': 'Usuarios',
      'max_products': 'Productos',
      'max_categories': 'Categorías',
      'max_tables': 'Mesas',
      'max_zones': 'Zonas',
      'max_orders_per_month': 'Pedidos por Mes',
      'max_customers': 'Clientes',
      'storage_gb': 'Almacenamiento (GB)',
      'api_calls_per_day': 'Llamadas API por Día',
    };
    return labels[key] ?? key;
  }

  /// Get actual usage value from backend data
  int _getUsageValue(String limitName) {
    final usage = controller.usage.value;
    if (usage == null) return 0;

    final usageValue = usage.usage[limitName];
    if (usageValue == null) return 0;
    if (usageValue is int) return usageValue;
    if (usageValue is double) return usageValue.toInt();
    return 0;
  }

  /// Calculate usage percentage based on actual usage from API
  double _calculateUsagePercentage(String limitName, int maxLimit) {
    final currentUsage = _getUsageValue(limitName);
    if (maxLimit == 0) return 0.0;
    return (currentUsage / maxLimit).clamp(0.0, 1.0);
  }

  /// Get progress bar color based on usage percentage
  Color _getProgressColor(double percentage) {
    if (percentage >= 0.9) return AppColors.error;
    if (percentage >= 0.7) return Colors.orange;
    return AppColors.primary;
  }
}
