import 'package:equatable/equatable.dart';
import '../../domain/entities/subscription_usage.dart';

/// Model for Subscription Usage
/// Contains plan info, limits, features and current usage
class SubscriptionUsageModel extends Equatable {
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

  const SubscriptionUsageModel({
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

  factory SubscriptionUsageModel.fromJson(Map<String, dynamic> json) {
    try {
      return SubscriptionUsageModel(
        planName: json['plan_name'] as String,
        planCode: json['plan_code'] as String,
        limits: json['limits'] as Map<String, dynamic>? ?? {},
        usage: json['usage'] as Map<String, dynamic>? ?? {},
        features: json['features'] as Map<String, dynamic>? ?? {},
        subscriptionStatus: json['subscription_status'] as String? ?? 'active',
        isTrial: json['is_trial'] as bool? ?? false,
        isTrialActive: json['is_trial_active'] as bool? ?? false,
        trialDaysRemaining: json['trial_days_remaining'] as int? ?? 0,
        trialEndsAt: json['trial_ends_at'] != null
            ? DateTime.parse(json['trial_ends_at'] as String)
            : null,
        currentPeriodEnd: json['current_period_end'] != null
            ? DateTime.parse(json['current_period_end'] as String)
            : null,
        startedAt: json['started_at'] != null
            ? DateTime.parse(json['started_at'] as String)
            : null,
      );
    } catch (e, stackTrace) {
      throw FormatException(
        'Error parsing SubscriptionUsageModel: $e\n$stackTrace',
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'plan_name': planName,
      'plan_code': planCode,
      'limits': limits,
      'usage': usage,
      'features': features,
      'subscription_status': subscriptionStatus,
      'is_trial': isTrial,
      'is_trial_active': isTrialActive,
      'trial_days_remaining': trialDaysRemaining,
      'trial_ends_at': trialEndsAt?.toIso8601String(),
      'current_period_end': currentPeriodEnd?.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
    };
  }

  SubscriptionUsage toEntity() {
    return SubscriptionUsage(
      planName: planName,
      planCode: planCode,
      limits: limits,
      usage: usage,
      features: features,
      subscriptionStatus: subscriptionStatus,
      isTrial: isTrial,
      isTrialActive: isTrialActive,
      trialDaysRemaining: trialDaysRemaining,
      trialEndsAt: trialEndsAt,
      currentPeriodEnd: currentPeriodEnd,
      startedAt: startedAt,
    );
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
