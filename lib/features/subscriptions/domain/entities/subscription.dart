import 'package:equatable/equatable.dart';
import 'subscription_plan.dart';

/// Subscription Entity
/// Represents a tenant's subscription in the domain layer
class Subscription extends Equatable {
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
  final SubscriptionPlan? plan;

  const Subscription({
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

  /// Check if subscription is active
  bool get isActive => status.toLowerCase() == 'active';

  /// Check if subscription is cancelled
  bool get isCancelled =>
      status.toLowerCase() == 'cancelled' || cancelledAt != null;

  /// Check if subscription is expired
  bool get isExpired => currentPeriodEnd.isBefore(DateTime.now());

  /// Check if trial is active
  bool get isTrialActive {
    if (!isTrial || trialEndsAt == null) return false;
    return trialEndsAt!.isAfter(DateTime.now());
  }

  /// Get days remaining in trial
  int? get trialDaysRemaining {
    if (!isTrial || trialEndsAt == null) return null;
    if (!isTrialActive) return 0;
    return trialEndsAt!.difference(DateTime.now()).inDays;
  }

  /// Get days remaining in current period
  int get daysRemainingInPeriod {
    return currentPeriodEnd.difference(DateTime.now()).inDays;
  }

  /// El trial de 30 días ya terminó y la cuenta se quedó en el plan
  /// Free sin elegir un plan pago — a partir de acá el backend bloquea
  /// crear pedidos, cobrar, gastos y nómina. Sin este chequeo, el status
  /// de la subscription queda en `active` (igual que un plan pago) y la
  /// pantalla mostraba "Activa" como si todo siguiera funcionando igual.
  bool get trialExpiredOnFreePlan {
    if (isTrial) return false; // todavía en trial, vigente o no
    return (plan?.isFree ?? false) && isActive;
  }

  /// Get status display text
  String get statusDisplay {
    if (isTrial && isTrialActive) {
      return 'Periodo de prueba';
    }
    if (trialExpiredOnFreePlan) {
      return 'Prueba vencida';
    }
    switch (status.toLowerCase()) {
      case 'active':
        return 'Activa';
      case 'cancelled':
        return 'Cancelada';
      case 'expired':
        return 'Expirada';
      case 'past_due':
        return 'Pago pendiente';
      default:
        return status;
    }
  }

  /// Get status color
  String get statusColor {
    if (isTrial && isTrialActive) return 'warning';
    if (trialExpiredOnFreePlan) return 'error';
    switch (status.toLowerCase()) {
      case 'active':
        return 'success';
      case 'cancelled':
      case 'expired':
        return 'error';
      case 'past_due':
        return 'warning';
      default:
        return 'default';
    }
  }

  /// Check if can upgrade
  bool get canUpgrade {
    return isActive && plan != null && !plan!.isFree;
  }

  /// Check if can cancel
  bool get canCancel {
    return isActive && !isCancelled;
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
