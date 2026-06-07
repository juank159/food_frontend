import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/responsive_config.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_gradient_header.dart';
import '../controllers/subscription_controller.dart';
import '../widgets/current_plan_card.dart';
import '../widgets/plan_comparison_card.dart';
import '../widgets/subscription_features_list.dart';
import '../widgets/trial_banner.dart';
import '../widgets/usage_limits_card.dart';

/// Pantalla de suscripción — gradient header con plan actual + ciclo
/// + chips de KPIs (estado, días de trial), seguido de las cards
/// existentes (CurrentPlanCard / UsageLimitsCard / Plans).
class SubscriptionPage extends GetView<SubscriptionController> {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody(responsive)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── Header ───────────────────────────

  Widget _buildHeader() {
    return Obx(() {
      final planName = controller.currentPlanName;
      final isTrial = controller.isOnTrial;
      final hasActive = controller.hasActiveSubscription;
      String statusLabel;
      if (isTrial) {
        statusLabel = 'En período de prueba';
      } else if (hasActive) {
        statusLabel = 'Suscripción activa';
      } else {
        statusLabel = 'Sin suscripción activa';
      }
      return AppGradientHeader(
        title: 'Mi suscripción',
        subtitle: statusLabel,
        leading: GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        trailing: Tooltip(
          message: 'Refrescar',
          child: Material(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: controller.refresh,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.refresh,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        hero: AppKpiHero(
          icon: Icons.workspace_premium,
          label: 'Plan actual',
          value: planName,
          hint: hasActive
              ? 'Activa hasta el próximo ciclo'
              : 'Elegí un plan para activar tu cuenta',
        ),
      );
    });
  }

  // ─────────────────────────── Body ───────────────────────────

  Widget _buildBody(ResponsiveConfig responsive) {
    return Obx(() {
      if (controller.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.hasError && !controller.hasActiveSubscription) {
        return AppErrorState(
          title: 'Error al cargar la suscripción',
          message: controller.errorMessage.value,
          onRetry: controller.refresh,
        );
      }
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: controller.refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(responsive.spacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (controller.isOnTrial) ...[
                const TrialBanner(),
                SizedBox(height: responsive.spacing),
              ],
              const CurrentPlanCard(),
              SizedBox(height: responsive.spacing),
              if (controller.usage.value != null) ...[
                const UsageLimitsCard(),
                SizedBox(height: responsive.spacing),
              ],
              if (controller.usage.value != null) ...[
                const SubscriptionFeaturesList(),
                SizedBox(height: responsive.spacing),
              ],
              if (controller.hasPlans) ...[
                _buildSectionTitle('Planes disponibles'),
                const SizedBox(height: 4),
                Text(
                  'Elegí el plan que mejor se adapte a tu negocio.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: responsive.spacing),
                const PlanComparisonCard(),
              ],
            ],
          ),
        ),
      );
    });
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
      ),
    );
  }
}
