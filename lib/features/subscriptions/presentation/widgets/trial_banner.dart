import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/navigation_service.dart';
import '../controllers/subscription_controller.dart';

class TrialBanner extends GetView<SubscriptionController> {
  const TrialBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final usage = controller.usage.value;
      if (usage == null) {
        return const SizedBox.shrink();
      }

      // Prueba vencida y sin plan pago: el backend ya está bloqueando
      // crear pedidos, cobrar, gastos y nómina — avisamos claro en vez
      // de dejar que se entere por un error al intentar vender.
      if (usage.trialExpiredOnFreePlan) {
        return _BlockedBanner(
          title: 'Tu prueba de 30 días terminó',
          subtitle: 'No podés crear pedidos, cobrar, registrar gastos ni '
              'nómina hasta elegir un plan.',
        );
      }

      // Plan pago sin gracia: expirado/cancelado o mora con gracia vencida.
      if (usage.paidPlanLapsed) {
        return const _BlockedBanner(
          title: 'Tu plan venció',
          subtitle: 'No podés crear pedidos, cobrar, registrar gastos ni '
              'nómina hasta renovarlo. Solicitá la renovación abajo y la '
              'activamos apenas recibamos el pago.',
        );
      }

      // Pago vencido pero dentro de los días de gracia: sigue operando.
      if (usage.inGracePeriod) {
        final until = usage.gracePeriodEndsAt!.toLocal();
        final d = until.difference(DateTime.now()).inDays;
        return _BlockedBanner(
          title: 'Tu plan venció — renovalo pronto',
          subtitle: 'Seguís operando normal hasta el '
              '${until.day}/${until.month}/${until.year}'
              '${d >= 1 ? ' ($d ${d == 1 ? 'día' : 'días'})' : ''}. '
              'Después se bloquean pedidos, cobros, gastos y nómina.',
          warning: true,
        );
      }

      if (!usage.isTrialActive) {
        return const SizedBox.shrink();
      }

      final daysRemaining = usage.trialDaysRemaining;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.access_time,
              color: AppColors.warning,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Periodo de Prueba',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    daysRemaining > 1
                        ? 'Te quedan $daysRemaining días de prueba gratuita'
                        : 'Tu prueba expira hoy',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: NavigationService.toSubscriptionPlans,
              icon: const Icon(Icons.arrow_forward, color: AppColors.warning),
            ),
          ],
        ),
      );
    });
  }
}

/// Banner rojo compartido para cualquier razón de bloqueo operativo
/// (prueba vencida sin plan, cobro fallido, suscripción cancelada).
class _BlockedBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool warning;

  const _BlockedBanner({
    required this.title,
    required this.subtitle,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = warning ? AppColors.warning : AppColors.error;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(warning ? Icons.schedule : Icons.lock_clock, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: NavigationService.toSubscriptionPlans,
            icon: Icon(Icons.arrow_forward, color: color),
          ),
        ],
      ),
    );
  }
}
