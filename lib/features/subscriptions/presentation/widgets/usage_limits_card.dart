import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../controllers/subscription_controller.dart';

/// Tarjeta de "Uso y Límites" de la suscripción.
///
/// **Único límite real del negocio: empleados (usuarios).** Decisión
/// explícita del dueño del producto — productos, categorías, mesas,
/// zonas, clientes y pedidos NUNCA se limitan ni se muestran acá,
/// aunque el backend llegara a mandar esos campos en `usage.limits`
/// (hoy ya no los manda — ver `SubscriptionPlansSeeder`). Por eso este
/// widget lee explícitamente `max_users`, no itera el mapa genérico:
/// así queda blindado incluso si algún día vuelve a aparecer otro
/// campo en la respuesta.
class UsageLimitsCard extends GetView<SubscriptionController> {
  const UsageLimitsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final usage = controller.usage.value;
      if (usage == null) return const SizedBox.shrink();

      final limitValue = usage.getLimit('max_users');
      if (limitValue == null) return const SizedBox.shrink();

      final isUnlimited = limitValue == -1;
      final used = usage.getUsage('max_users') ?? 0;
      // Caso raro (no debería pasar con el enforcement del backend,
      // pero por las dudas si el conteo cambió entre requests): avisar
      // en vez de mostrar una barra rota o un número que no cuadra.
      final isOver = !isUnlimited && limitValue > 0 && used > limitValue;
      final percentage = isUnlimited || limitValue == 0
          ? 0.0
          : (used / limitValue).clamp(0.0, 1.0);

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
                  'Usuarios',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Empleados con cuenta',
                    style: TextStyle(
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
                  isUnlimited ? 'Ilimitado' : '$used / $limitValue',
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
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getProgressColor(percentage),
                ),
              ),
            ],
            if (isOver) ...[
              const SizedBox(height: 6),
              const Text(
                'No podés agregar más empleados hasta mejorar tu plan. '
                'Los que ya tenés siguen funcionando normal.',
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
    });
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 0.9) return AppColors.error;
    if (percentage >= 0.7) return Colors.orange;
    return AppColors.primary;
  }
}
