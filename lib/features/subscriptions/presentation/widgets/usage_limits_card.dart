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
              final used = _getUsageValue(entry.key);
              // Excedido de verdad: la barra se topa al 100%, así que sin
              // este aviso "772 de 500" se veía igual que estar justo en
              // el límite y nadie se enteraba.
              final isOver = !isUnlimited && limit > 0 && used > limit;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _getLimitLabel(entry.key),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isOver) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Excedido',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          isUnlimited ? 'Ilimitado' : '$used / $limit',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isUnlimited
                                ? AppColors.success
                                : (isOver
                                    ? AppColors.error
                                    : AppColors.primary),
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
                    if (isOver) ...[
                      const SizedBox(height: 6),
                      Text(
                        _overLimitHint(entry.key),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.error,
                          height: 1.3,
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

  /// Qué significa en la práctica estar excedido, que NO es lo mismo
  /// para todos los recursos:
  ///   - Configuración (usuarios, productos, categorías, mesas, zonas):
  ///     el backend bloquea crear más (ver `PlanLimitsService`).
  ///   - Volumen (pedidos del mes, clientes): NO se bloquea a propósito
  ///     — cortarle los pedidos a un restaurante en plena jornada sería
  ///     dejarlo sin vender, y los clientes se crean solos cuando la
  ///     gente pide por QR.
  String _overLimitHint(String key) {
    const blocked = {
      'max_users',
      'max_products',
      'max_categories',
      'max_tables',
      'max_zones',
    };
    if (blocked.contains(key)) {
      return 'No podés agregar más hasta mejorar tu plan. '
          'Los que ya tenés siguen funcionando normal.';
    }
    return 'Podés seguir operando con normalidad. '
        'Mejorá tu plan para quedar al día.';
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
