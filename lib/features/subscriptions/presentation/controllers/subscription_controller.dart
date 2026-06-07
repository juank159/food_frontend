import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/entities/subscription_usage.dart';
import '../../domain/usecases/cancel_subscription_usecase.dart';
import '../../domain/usecases/change_plan_usecase.dart';
import '../../domain/usecases/get_current_subscription_usecase.dart';
import '../../domain/usecases/get_plans_usecase.dart';
import '../../domain/usecases/get_usage_usecase.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Subscription Controller
/// Manages all subscription-related state and business logic
class SubscriptionController extends GetxController {
  final GetPlansUseCase getPlansUseCase;
  final GetCurrentSubscriptionUseCase getCurrentSubscriptionUseCase;
  final GetUsageUseCase getUsageUseCase;
  final ChangePlanUseCase changePlanUseCase;
  final CancelSubscriptionUseCase cancelSubscriptionUseCase;

  SubscriptionController({
    required this.getPlansUseCase,
    required this.getCurrentSubscriptionUseCase,
    required this.getUsageUseCase,
    required this.changePlanUseCase,
    required this.cancelSubscriptionUseCase,
  });

  // Observable states
  final RxList<SubscriptionPlan> plans = <SubscriptionPlan>[].obs;
  final Rx<Subscription?> currentSubscription = Rx<Subscription?>(null);
  final Rx<SubscriptionUsage?> usage = Rx<SubscriptionUsage?>(null);

  final RxBool isLoadingPlans = false.obs;
  final RxBool isLoadingSubscription = false.obs;
  final RxBool isLoadingUsage = false.obs;
  final RxBool isChangingPlan = false.obs;
  final RxBool isCancelling = false.obs;

  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadAllData();
  }

  /// Load all subscription data
  Future<void> loadAllData() async {
    await Future.wait([
      loadPlans(),
      loadCurrentSubscription(),
      loadUsage(),
    ]);
  }

  /// Load all available plans
  Future<void> loadPlans() async {
    isLoadingPlans.value = true;
    errorMessage.value = '';

    final result = await getPlansUseCase();

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        isLoadingPlans.value = false;
      },
      (plansList) {
        plans.value = plansList.where((p) => p.isActive).toList();
        isLoadingPlans.value = false;
      },
    );
  }

  /// Load current subscription
  Future<void> loadCurrentSubscription() async {
    isLoadingSubscription.value = true;

    final result = await getCurrentSubscriptionUseCase();

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        isLoadingSubscription.value = false;
      },
      (subscription) {
        currentSubscription.value = subscription;
        isLoadingSubscription.value = false;
      },
    );
  }

  /// Load subscription usage and limits
  Future<void> loadUsage() async {
    isLoadingUsage.value = true;

    final result = await getUsageUseCase();

    result.fold(
      (failure) {
        isLoadingUsage.value = false;
      },
      (usageData) {
        usage.value = usageData;
        isLoadingUsage.value = false;
      },
    );
  }

  /// Change subscription plan
  Future<void> changePlan(
    String planCode, {
    String? billingCycle,
  }) async {
    isChangingPlan.value = true;
    errorMessage.value = '';

    final result = await changePlanUseCase(
      ChangePlanParams(
        planCode: planCode,
        billingCycle: billingCycle,
      ),
    );

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        isChangingPlan.value = false;
        AppSnackbar.show(
          'Error',
          failure.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.red.shade900,
          icon: const Icon(Icons.error_outline, color: Colors.red),
          duration: const Duration(seconds: 4),
        );
      },
      (subscription) {
        currentSubscription.value = subscription;
        isChangingPlan.value = false;
        AppSnackbar.show(
          'Éxito',
          'Plan cambiado exitosamente',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
          colorText: Colors.green.shade900,
          icon: const Icon(Icons.check_circle_outline, color: Colors.green),
          duration: const Duration(seconds: 3),
        );
        loadUsage(); // Refresh usage data
      },
    );
  }

  /// Cancel subscription
  Future<void> cancelSubscription({
    required bool immediately,
    String? reason,
  }) async {
    isCancelling.value = true;
    errorMessage.value = '';

    final result = await cancelSubscriptionUseCase(
      CancelSubscriptionParams(
        immediately: immediately,
        reason: reason,
      ),
    );

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        isCancelling.value = false;
        AppSnackbar.show(
          'Error',
          failure.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.red.shade900,
          icon: const Icon(Icons.error_outline, color: Colors.red),
          duration: const Duration(seconds: 4),
        );
      },
      (subscription) {
        currentSubscription.value = subscription;
        isCancelling.value = false;
        AppSnackbar.show(
          'Éxito',
          immediately
              ? 'Suscripción cancelada'
              : 'La suscripción se cancelará al final del periodo',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
          colorText: Colors.green.shade900,
          icon: const Icon(Icons.check_circle_outline, color: Colors.green),
          duration: const Duration(seconds: 3),
        );
      },
    );
  }

  /// Refresh all data
  @override
  Future<void> refresh() async {
    await loadAllData();
  }

  // Computed properties
  bool get hasActiveSubscription =>
      currentSubscription.value?.isActive ?? false;

  bool get isOnTrial => currentSubscription.value?.isTrialActive ?? false;

  String get currentPlanCode => usage.value?.planCode ?? 'free';

  String get currentPlanName => usage.value?.planName ?? 'Gratis';

  bool get hasPlans => plans.isNotEmpty;

  bool get hasError => errorMessage.value.isNotEmpty;

  bool get isLoading =>
      isLoadingPlans.value ||
      isLoadingSubscription.value ||
      isLoadingUsage.value;

  /// Check if can upgrade to a specific plan
  bool canUpgradeTo(SubscriptionPlan plan) {
    if (!hasActiveSubscription) return true;
    final current = currentSubscription.value;
    if (current == null || current.plan == null) return true;
    return plan.price > current.plan!.price;
  }

  /// Check if can downgrade to a specific plan
  bool canDowngradeTo(SubscriptionPlan plan) {
    if (!hasActiveSubscription) return false;
    final current = currentSubscription.value;
    if (current == null || current.plan == null) return false;
    return plan.price < current.plan!.price;
  }

  /// Check if plan is current
  bool isCurrentPlan(SubscriptionPlan plan) {
    return plan.code == currentPlanCode;
  }

  /// Get plan by code
  SubscriptionPlan? getPlanByCode(String code) {
    try {
      return plans.firstWhere((p) => p.code == code);
    } catch (e) {
      return null;
    }
  }
}
