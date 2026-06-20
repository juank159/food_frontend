import '../../domain/entities/customer_address.dart';
import '../../../../core/utils/json_parsers.dart';
import 'package:json_annotation/json_annotation.dart';

/// Customer Address Model
///
/// Modelo de transferencia que mapea el shape del backend
/// (`customer_addresses`) a la entidad de dominio. Hand-written: el backend
/// devuelve `latitude`/`longitude` como string desde Postgres NUMERIC y
/// algunos campos opcionales pueden faltar.
class CustomerAddressModel {
  final String id;
  final String customerId;
  final String label;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String? state;
  final String? postalCode;
  @JsonKey(fromJson: JsonParsers.parseNullableDouble)
  final double? latitude;
  @JsonKey(fromJson: JsonParsers.parseNullableDouble)
  final double? longitude;
  final String? deliveryInstructions;
  final bool isDefault;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const CustomerAddressModel({
    required this.id,
    required this.customerId,
    required this.label,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    this.state,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.deliveryInstructions,
    this.isDefault = false,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  CustomerAddress toEntity() {
    return CustomerAddress(
      id: id,
      customerId: customerId,
      label: label,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      city: city,
      state: state,
      postalCode: postalCode,
      latitude: latitude,
      longitude: longitude,
      deliveryInstructions: deliveryInstructions,
      isDefault: isDefault,
      isActive: isActive,
      createdAt: DateTime.tryParse(createdAt) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(updatedAt) ?? DateTime.now(),
    );
  }

  factory CustomerAddressModel.fromJson(Map<String, dynamic> json) {
    double? parseDecimal(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return CustomerAddressModel(
      id: (json['id'] as String?) ?? '',
      customerId: (json['customer_id'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      addressLine1: (json['address_line1'] as String?) ?? '',
      addressLine2: json['address_line2'] as String?,
      city: (json['city'] as String?) ?? '',
      state: json['state'] as String?,
      postalCode: json['postal_code'] as String?,
      latitude: parseDecimal(json['latitude']),
      longitude: parseDecimal(json['longitude']),
      deliveryInstructions: json['delivery_instructions'] as String?,
      isDefault: (json['is_default'] as bool?) ?? false,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: (json['created_at'] as String?) ?? '',
      updatedAt: (json['updated_at'] as String?) ?? '',
    );
  }
}
