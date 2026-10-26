import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../controllers/subscription_controller.dart';

/// Tarjeta de "Uso y Límites" de la suscripción.
///
/// **Únicos límites reales del negocio: empleados y sedes.** Decisión
/// explícita del dueño del producto — productos, categorías, mesas,
/// zonas, clientes y pedidos NUNCA se limitan ni se muestran acá,
/// aunque el backend llegara a mandar esos campos en `usage.limits`.
/// Por eso este widget lee explícitamente `max_users` y `max_branches`,
/// no itera el mapa genérico.
class UsageLimitsCard extends GetView<SubscriptionController> {
  const UsageLimitsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final usage = controller.usage.value;
      if (usage == null) return const SizedBox.shrink();

      final usersLimit = usage.getLimit('max_users');
      final branchesLimit = usage.getLimit('max_branches');
      if (usersLimit == null && branchesLimit == null) {
        return const SizedBox.shrink();
      }

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
                Icon(Icons.people_outline, color: AppColors.primary, size: 24),
                SizedBox(width: 12),
                Text(
                  'Uso del plan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            if (usersLimit != null) ...[
              const SizedBox(height: 20),
              _LimitRow(
                label: 'Empleados con cuenta',
                used: usage.getUsage('max_users') ?? 0,
                limit: usersLimit,
                overText: 'No podés agregar más empleados hasta mejorar tu plan. '
                    'Los que ya tenés siguen funcionando normal.',
              ),
            ],
            if (branchesLimit != null) ...[
              const SizedBox(height: 20),
              _LimitRow(
                label: 'Sedes activas',
                used: usage.getUsage('max_branches') ?? 1,
                limit: branchesLimit,
                overText: 'No podés activar más sedes hasta mejorar tu plan. '
                    'Las que ya tenés siguen funcionando normal.',
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _LimitRow extends StatelessWidget {
  final String label;
  final int used;
  final int limit;
  final String overText;

  const _LimitRow({
    required this.label,
    required this.used,
    required this.limit,
    required this.overText,
  });

  @override
  Widget build(BuildContext context) {
    final isUnlimited = limit == -1;
    // Caso raro (no debería pasar con el enforcement del backend, pero
    // por las dudas si el conteo cambió entre requests o se bajó de
    // plan): avisar en vez de mostrar una barra rota.
    final isOver = !isUnlimited && limit > 0 && used > limit;
    final percentage =
        isUnlimited || limit == 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (isOver) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
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
                    : (isOver ? AppColors.error : AppColors.primary),
              ),
            ),
          ],
        ),
        if (!isUnlimited) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(_progressColor(percentage)),
          ),
        ],
        if (isOver) ...[
          const SizedBox(height: 6),
          Text(
            overText,
            style: const TextStyle(fontSize: 11, color: AppColors.error, height: 1.3),
          ),
        ],
      ],
    );
  }

  Color _progressColor(double percentage) {
    if (percentage >= 0.9) return AppColors.error;
    if (percentage >= 0.7) return Colors.orange;
    return AppColors.primary;
  }
}
