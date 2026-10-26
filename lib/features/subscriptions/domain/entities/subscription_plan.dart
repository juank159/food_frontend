import 'package:equatable/equatable.dart';
import '../../../../core/config/formatters/currency_formatter.dart';

/// Subscription Plan Entity
/// Represents a subscription plan in the domain layer
class SubscriptionPlan extends Equatable {
  final String id;
  final String code;
  final String name;
  final String description;
  /// Precio mensual (= `price_monthly`). Semestral y anual son el valor
  /// TOTAL del período, con descuento (ver [priceFor]).
  final double price;
  final double priceSemiannual;
  final double priceYearly;
  final String currency;
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
    this.priceSemiannual = 0,
    this.priceYearly = 0,
    this.currency = 'COP',
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

  /// Meses que cubre cada ciclo de cobro.
  static int monthsOf(String cycle) => switch (cycle) {
        'semiannual' => 6,
        'yearly' => 12,
        _ => 1,
      };

  /// Valor total a pagar por el ciclo (mensual, semestral o anual).
  double priceFor(String cycle) => switch (cycle) {
        'semiannual' => priceSemiannual > 0 ? priceSemiannual : price * 6,
        'yearly' => priceYearly > 0 ? priceYearly : price * 12,
        _ => price,
      };

  /// Lo que sale por mes pagando ese ciclo.
  double monthlyEquivalent(String cycle) => priceFor(cycle) / monthsOf(cycle);

  /// Ahorro total frente a pagar mes a mes durante el mismo período.
  double savingsFor(String cycle) =>
      price * monthsOf(cycle) - priceFor(cycle);

  static String cycleLabel(String cycle) => switch (cycle) {
        'semiannual' => 'Semestral',
        'yearly' => 'Anual',
        _ => 'Mensual',
      };

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
      case 'semiannual':
        return 'por 6 meses';
      case 'yearly':
        return 'al año';
      case 'quarterly':
        return 'al trimestre';
      default:
        return billingCycle;
    }
  }

  /// Get full price description
  ///
  /// El plan Free NO es "para siempre" — es el plan al que cae la cuenta
  /// cuando termina el trial de 30 días sin que se haya elegido un plan
  /// pago, y a partir de ahí el backend bloquea crear pedidos, cobrar,
  /// gastos y nómina (`TenantInterceptor.assertCanCreate`). Decirle al
  /// usuario "gratis para siempre" acá era literalmente falso.
  String get priceDescription {
    if (price == 0) {
      return hasTrialPeriod
          ? 'Gratis los primeros $trialDays días'
          : 'Gratis';
    }
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
        priceSemiannual,
        priceYearly,
        currency,
        billingCycle,
        trialDays,
        isActive,
        features,
        limits,
      ];
}
