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

      // Plan pago (Basic/Professional) que dejó de estar al día: el
      // último cobro falló (en período de gracia) o la suscripción está
      // cancelada/expirada. Mismo bloqueo operativo — mismo aviso.
      if (usage.paidPlanLapsed) {
        final isPastDue = usage.subscriptionStatus.toLowerCase() == 'past_due';
        return _BlockedBanner(
          title: isPastDue ? 'Tu plan está vencido' : 'Tu suscripción terminó',
          subtitle: isPastDue
              ? 'El último cobro no se pudo procesar. No podés crear '
                  'pedidos, cobrar, registrar gastos ni nómina hasta '
                  'regularizar el pago.'
              : 'No podés crear pedidos, cobrar, registrar gastos ni '
                  'nómina hasta renovar tu plan.',
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

  const _BlockedBanner({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_clock, color: AppColors.error, size: 28),
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
            icon: const Icon(Icons.arrow_forward, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}
