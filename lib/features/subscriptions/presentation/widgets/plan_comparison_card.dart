import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/responsive_config.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../domain/entities/subscription_plan.dart';
import '../controllers/subscription_controller.dart';

class PlanComparisonCard extends GetView<SubscriptionController> {
  const PlanComparisonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Obx(() {
      if (controller.plans.isEmpty) {
        return const SizedBox.shrink();
      }

      if (responsive.isMobile) {
        return Column(
          children: controller.plans.map((plan) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildPlanCard(plan, context),
            );
          }).toList(),
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: controller.plans.map((plan) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _buildPlanCard(plan, context),
            ),
          );
        }).toList(),
      );
    });
  }

  Widget _buildPlanCard(SubscriptionPlan plan, BuildContext context) {
    final isCurrent = controller.isCurrentPlan(plan);
    final canUpgrade = controller.canUpgradeTo(plan);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? AppColors.primary : AppColors.border,
          width: isCurrent ? 2 : 1,
        ),
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
          if (isCurrent) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'PLAN ACTUAL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textOnPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            plan.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            plan.priceDescription,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            plan.description,
            textAlign: TextAlign.justify,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          if (!isCurrent) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: controller.isChangingPlan.value
                    ? null
                    : () => _confirmPlanChange(plan, context),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      canUpgrade ? AppColors.primary : AppColors.secondary,
                  foregroundColor: AppColors.textOnPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(canUpgrade ? 'Actualizar' : 'Cambiar'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmPlanChange(SubscriptionPlan plan, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cambiar a ${plan.name}'),
        content: Text(
          '¿Deseas cambiar tu plan a ${plan.name} por ${plan.priceDescription}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller.changePlan(plan.code);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}
