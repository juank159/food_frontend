import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/navigation_service.dart';
import '../../domain/entities/subscription_plan.dart';
import '../controllers/subscription_controller.dart';

class CurrentPlanCard extends GetView<SubscriptionController> {
  const CurrentPlanCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final subscription = controller.currentSubscription.value;
      if (subscription == null) {
        return const SizedBox.shrink();
      }

      final usage = controller.usage.value;
      final cycle = usage?.billingCycle ?? 'monthly';
      final status = subscription.status.toLowerCase();
      final isPaid =
          subscription.plan != null && !subscription.plan!.isFree;
      // Qué fecha importa según el estado (el cobro es manual: no hay
      // "renovación automática", hay "vigente hasta").
      String? dateLine;
      int? warnDays;
      if (subscription.isTrial && subscription.trialEndsAt != null) {
        dateLine = 'Prueba hasta ${_formatDate(subscription.trialEndsAt!)}';
      } else if (isPaid && status == 'active') {
        dateLine =
            'Vigente hasta ${_formatDate(subscription.currentPeriodEnd)}';
        final d = subscription.daysRemainingInPeriod;
        if (d <= 7) warnDays = d;
      } else if (isPaid && status == 'past_due') {
        final grace = usage?.gracePeriodEndsAt;
        dateLine = 'Venció el ${_formatDate(subscription.currentPeriodEnd)}'
            '${grace != null ? ' · podés operar hasta el ${_formatDate(grace)}' : ''}';
      } else if (isPaid && status == 'expired') {
        dateLine = 'Venció el ${_formatDate(subscription.currentPeriodEnd)}';
      }

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plan Actual',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textOnPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      controller.currentPlanName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.textOnPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    subscription.statusDisplay,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (subscription.plan != null && !subscription.plan!.isFree) ...[
              Text(
                '${CurrencyFormatter.format(subscription.plan!.priceFor(cycle))} '
                '· ${SubscriptionPlan.cycleLabel(cycle).toLowerCase()}',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textOnPrimary.withValues(alpha: 0.9),
                ),
              ),
            ],
            if (dateLine != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: AppColors.textOnPrimary.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dateLine,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textOnPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (warnDays != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    warnDays <= 0
                        ? 'Vence hoy'
                        : 'Faltan $warnDays ${warnDays == 1 ? 'día' : 'días'}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: NavigationService.toSubscriptionPlans,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textOnPrimary,
                      side: const BorderSide(color: AppColors.textOnPrimary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Ver Planes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  String _formatDate(DateTime date) {
    final d = date.toLocal();
    return '${d.day}/${d.month}/${d.year}';
  }
}
