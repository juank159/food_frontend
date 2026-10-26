import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/entities/subscription_usage.dart';
import '../../domain/usecases/cancel_subscription_usecase.dart';
import '../../domain/usecases/get_current_subscription_usecase.dart';
import '../../domain/usecases/get_plans_usecase.dart';
import '../../domain/usecases/get_usage_usecase.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../data/datasources/plan_billing_api.dart';

/// Subscription Controller
/// Manages all subscription-related state and business logic
class SubscriptionController extends GetxController {
  final GetPlansUseCase getPlansUseCase;
  final GetCurrentSubscriptionUseCase getCurrentSubscriptionUseCase;
  final GetUsageUseCase getUsageUseCase;
  final CancelSubscriptionUseCase cancelSubscriptionUseCase;
  final PlanBillingApi billingApi;

  SubscriptionController({
    required this.getPlansUseCase,
    required this.getCurrentSubscriptionUseCase,
    required this.getUsageUseCase,
    required this.cancelSubscriptionUseCase,
    required this.billingApi,
  });

  // Observable states
  final RxList<SubscriptionPlan> plans = <SubscriptionPlan>[].obs;
  final Rx<Subscription?> currentSubscription = Rx<Subscription?>(null);
  final Rx<SubscriptionUsage?> usage = Rx<SubscriptionUsage?>(null);

  final RxBool isLoadingPlans = false.obs;
  final RxBool isLoadingSubscription = false.obs;
  final RxBool isLoadingUsage = false.obs;
  final RxBool isChangingPlan = false.obs;

  /// Ciclo elegido en el selector de planes: monthly | semiannual | yearly.
  final RxString selectedCycle = 'monthly'.obs;

  /// Solicitud de plan pendiente de aprobación (o `null`).
  final Rx<Map<String, dynamic>?> pendingRequest =
      Rx<Map<String, dynamic>?>(null);

  /// El usuario administra la plataforma (aprueba pagos de los negocios).
  final RxBool isPlatformAdmin = false.obs;
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
      loadPendingRequest(),
      _loadPlatformAdmin(),
    ]);
  }

  Future<void> loadPendingRequest() async {
    try {
      pendingRequest.value = await billingApi.pendingRequest();
    } catch (_) {
      // Sin red o sin permiso (no es el dueño): simplemente no se muestra.
    }
  }

  Future<void> _loadPlatformAdmin() async {
    isPlatformAdmin.value = await billingApi.isPlatformAdmin();
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

  /// Solicita un plan pago. No cambia nada todavía: la plataforma lo
  /// activa cuando recibe el pago.
  Future<bool> requestPlan(String planCode, String billingCycle,
      {String? notes}) async {
    isChangingPlan.value = true;
    try {
      pendingRequest.value = await billingApi.requestPlan(
        planCode: planCode,
        billingCycle: billingCycle,
        notes: notes,
      );
      return true;
    } catch (e) {
      AppSnackbar.show(
        'No se pudo enviar la solicitud',
        PlanBillingApi.messageOf(e),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
        icon: const Icon(Icons.error_outline, color: Colors.red),
        duration: const Duration(seconds: 4),
      );
      return false;
    } finally {
      isChangingPlan.value = false;
    }
  }

  Future<void> cancelPendingRequest() async {
    isChangingPlan.value = true;
    try {
      await billingApi.cancelRequest();
      pendingRequest.value = null;
    } catch (e) {
      AppSnackbar.show(
        'Error',
        PlanBillingApi.messageOf(e),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
        icon: const Icon(Icons.error_outline, color: Colors.red),
      );
    } finally {
      isChangingPlan.value = false;
    }
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
