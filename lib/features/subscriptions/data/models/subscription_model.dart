import 'package:equatable/equatable.dart';
import '../../domain/entities/subscription.dart';
import 'subscription_plan_model.dart';

/// Model for Subscription
/// Maps API response to domain entity
class SubscriptionModel extends Equatable {
  final String id;
  final String tenantId;
  final String planId;
  final String status;
  final bool isTrial;
  final DateTime? trialEndsAt;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SubscriptionPlanModel? plan;

  const SubscriptionModel({
    required this.id,
    required this.tenantId,
    required this.planId,
    required this.status,
    required this.isTrial,
    this.trialEndsAt,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    this.cancelledAt,
    this.cancellationReason,
    required this.createdAt,
    required this.updatedAt,
    this.plan,
  });

  /// Create from JSON with robust error handling
  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    try {
      return SubscriptionModel(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        planId: json['plan_id'] as String,
        status: json['status'] as String? ?? 'active',
        isTrial: json['is_trial'] as bool? ?? false,
        trialEndsAt: json['trial_ends_at'] != null
            ? DateTime.parse(json['trial_ends_at'] as String)
            : null,
        currentPeriodStart: json['started_at'] != null
            ? DateTime.parse(json['started_at'] as String)
            : DateTime.parse(json['current_period_start'] as String),
        currentPeriodEnd: DateTime.parse(json['current_period_end'] as String),
        cancelledAt: json['cancelled_at'] != null
            ? DateTime.parse(json['cancelled_at'] as String)
            : null,
        cancellationReason: json['cancellation_reason'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        plan: json['plan'] != null
            ? SubscriptionPlanModel.fromJson(
                json['plan'] as Map<String, dynamic>)
            : null,
      );
    } catch (e, stackTrace) {
      throw FormatException(
        'Error parsing SubscriptionModel: $e\n$stackTrace',
      );
    }
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'plan_id': planId,
      'status': status,
      'is_trial': isTrial,
      'trial_ends_at': trialEndsAt?.toIso8601String(),
      'current_period_start': currentPeriodStart.toIso8601String(),
      'current_period_end': currentPeriodEnd.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'cancellation_reason': cancellationReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (plan != null) 'plan': plan!.toJson(),
    };
  }

  /// Convert to domain entity
  Subscription toEntity() {
    return Subscription(
      id: id,
      tenantId: tenantId,
      planId: planId,
      status: status,
      isTrial: isTrial,
      trialEndsAt: trialEndsAt,
      currentPeriodStart: currentPeriodStart,
      currentPeriodEnd: currentPeriodEnd,
      cancelledAt: cancelledAt,
      cancellationReason: cancellationReason,
      createdAt: createdAt,
      updatedAt: updatedAt,
      plan: plan?.toEntity(),
    );
  }

  /// Create from domain entity
  factory SubscriptionModel.fromEntity(Subscription subscription) {
    return SubscriptionModel(
      id: subscription.id,
      tenantId: subscription.tenantId,
      planId: subscription.planId,
      status: subscription.status,
      isTrial: subscription.isTrial,
      trialEndsAt: subscription.trialEndsAt,
      currentPeriodStart: subscription.currentPeriodStart,
      currentPeriodEnd: subscription.currentPeriodEnd,
      cancelledAt: subscription.cancelledAt,
      cancellationReason: subscription.cancellationReason,
      createdAt: subscription.createdAt,
      updatedAt: subscription.updatedAt,
      plan: subscription.plan != null
          ? SubscriptionPlanModel.fromEntity(subscription.plan!)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        tenantId,
        planId,
        status,
        isTrial,
        trialEndsAt,
        currentPeriodStart,
        currentPeriodEnd,
        cancelledAt,
        cancellationReason,
        createdAt,
        updatedAt,
        plan,
      ];
}
