import 'package:equatable/equatable.dart';
import '../../../../core/config/formatters/currency_formatter.dart';

/// Subscription Plan Entity
/// Represents a subscription plan in the domain layer
class SubscriptionPlan extends Equatable {
  final String id;
  final String code;
  final String name;
  final String description;
  final double price;
  final String billingCycle;
  final int trialDays;
  final bool isActive;
  final Map<String, dynamic> features;
  final Map<String, dynamic> limits;

  const SubscriptionPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.price,
    required this.billingCycle,
    required this.trialDays,
    required this.isActive,
    required this.features,
    required this.limits,
  });

  /// Check if a specific feature is available
  bool hasFeature(String featureName) {
    return features[featureName] == true;
  }

  /// Get limit value for a specific resource
  int? getLimit(String limitName) {
    final value = limits[limitName];
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Check if limit is unlimited (-1)
  bool isUnlimited(String limitName) {
    return getLimit(limitName) == -1;
  }

  /// Get formatted price
  String get formattedPrice {
    if (price == 0) return 'Gratis';
    return CurrencyFormatter.format(price);
  }

  /// Get formatted billing cycle
  String get formattedBillingCycle {
    switch (billingCycle.toLowerCase()) {
      case 'monthly':
        return 'al mes';
      case 'yearly':
        return 'al año';
      case 'quarterly':
        return 'al trimestre';
      default:
        return billingCycle;
    }
  }

  /// Get full price description
  String get priceDescription {
    if (price == 0) return 'Gratis para siempre';
    return '$formattedPrice $formattedBillingCycle';
  }

  /// Check if this is a free plan
  bool get isFree => price == 0 || code.toLowerCase() == 'free';

  /// Check if this is a trial eligible plan
  bool get hasTrialPeriod => trialDays > 0;

  @override
  List<Object?> get props => [
        id,
        code,
        name,
        description,
        price,
        billingCycle,
        trialDays,
        isActive,
        features,
        limits,
      ];
}
