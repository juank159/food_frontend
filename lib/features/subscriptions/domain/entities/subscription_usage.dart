import 'package:equatable/equatable.dart';

/// Subscription Usage Entity
/// Represents the current usage and limits of a subscription
class SubscriptionUsage extends Equatable {
  final String planName;
  final String planCode;
  final Map<String, dynamic> limits;
  final Map<String, dynamic> usage;
  final Map<String, dynamic> features;
  final String subscriptionStatus;
  final bool isTrial;
  final bool isTrialActive;
  final int trialDaysRemaining;
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodEnd;
  final DateTime? startedAt;

  const SubscriptionUsage({
    required this.planName,
    required this.planCode,
    required this.limits,
    required this.usage,
    required this.features,
    required this.subscriptionStatus,
    required this.isTrial,
    required this.isTrialActive,
    required this.trialDaysRemaining,
    this.trialEndsAt,
    this.currentPeriodEnd,
    this.startedAt,
  });

  /// Check if a feature is available
  bool hasFeature(String featureName) {
    return features[featureName] == true;
  }

  /// Get limit for a resource
  int? getLimit(String limitName) {
    final value = limits[limitName];
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Check if limit is unlimited
  bool isUnlimited(String limitName) {
    return getLimit(limitName) == -1;
  }

  /// El trial de 30 días ya terminó y la cuenta se quedó en el plan Free
  /// sin elegir un plan pago — el backend bloquea crear pedidos, cobrar,
  /// gastos y nómina a partir de acá (`TenantInterceptor.assertCanCreate`).
  bool get trialExpiredOnFreePlan {
    if (isTrial) return false; // todavía en trial, vigente o no
    return planCode.toLowerCase() == 'free' &&
        subscriptionStatus.toLowerCase() == 'active';
  }

  /// Check if limit is reached
  bool isLimitReached(String limitName, int currentUsage) {
    final limit = getLimit(limitName);
    if (limit == null || limit == -1) return false;
    return currentUsage >= limit;
  }

  /// Get actual usage from backend data
  int? getUsage(String limitName) {
    final value = usage[limitName];
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Get usage percentage for a limit using real backend data
  double getUsagePercentage(String limitName) {
    final limit = getLimit(limitName);
    final currentUsage = getUsage(limitName);

    if (limit == null || limit == -1 || limit == 0) return 0.0;
    if (currentUsage == null) return 0.0;

    return (currentUsage / limit).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [
        planName,
        planCode,
        limits,
        usage,
        features,
        subscriptionStatus,
        isTrial,
        isTrialActive,
        trialDaysRemaining,
        trialEndsAt,
        currentPeriodEnd,
        startedAt,
      ];
}
