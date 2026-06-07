import 'package:equatable/equatable.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../../../core/utils/json_parsers.dart';
import 'package:json_annotation/json_annotation.dart';

/// Model for Subscription Plan
/// Maps API response to domain entity
class SubscriptionPlanModel extends Equatable {
  final String id;
  final String code;
  final String name;
  final String description;
  @JsonKey(fromJson: JsonParsers.parseDouble)
  final double price;
  final String billingCycle;
  final int trialDays;
  final bool isActive;
  final Map<String, dynamic> features;
  final Map<String, dynamic> limits;

  const SubscriptionPlanModel({
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

  /// Create from JSON with robust error handling
  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    try {
      return SubscriptionPlanModel(
        id: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        price: _parseDouble(json['price']),
        billingCycle: json['billing_cycle'] as String? ?? 'monthly',
        trialDays: _parseInt(json['trial_days']),
        isActive: json['is_active'] as bool? ?? true,
        features: json['features'] as Map<String, dynamic>? ?? {},
        limits: json['limits'] as Map<String, dynamic>? ?? {},
      );
    } catch (e, stackTrace) {
      throw FormatException(
        'Error parsing SubscriptionPlanModel: $e\n$stackTrace',
      );
    }
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'price': price,
      'billing_cycle': billingCycle,
      'trial_days': trialDays,
      'is_active': isActive,
      'features': features,
      'limits': limits,
    };
  }

  /// Convert to domain entity
  SubscriptionPlan toEntity() {
    return SubscriptionPlan(
      id: id,
      code: code,
      name: name,
      description: description,
      price: price,
      billingCycle: billingCycle,
      trialDays: trialDays,
      isActive: isActive,
      features: features,
      limits: limits,
    );
  }

  /// Create from domain entity
  factory SubscriptionPlanModel.fromEntity(SubscriptionPlan plan) {
    return SubscriptionPlanModel(
      id: plan.id,
      code: plan.code,
      name: plan.name,
      description: plan.description,
      price: plan.price,
      billingCycle: plan.billingCycle,
      trialDays: plan.trialDays,
      isActive: plan.isActive,
      features: plan.features,
      limits: plan.limits,
    );
  }

  /// Helper to parse double values
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Helper to parse int values
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

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
