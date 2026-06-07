import '../../domain/entities/customer.dart';
import 'customer_address_model.dart';
import '../../../../core/utils/json_parsers.dart';
import 'package:json_annotation/json_annotation.dart';

/// Customer Model
///
/// Mapea la respuesta del backend (`customers`) a la entidad de dominio.
/// Hand-written para tolerar el wire format real:
///   - `total_spent` viene como string desde Postgres NUMERIC.
///   - `last_order_date` puede venir como `YYYY-MM-DD` (sin hora) o ISO.
///   - `addresses` es opcional según el endpoint.
class CustomerModel {
  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final String? defaultAddressId;
  final int totalOrders;
  @JsonKey(fromJson: JsonParsers.parseDouble)
  final double totalSpent;
  final String? lastOrderDate;
  final String? notes;
  final bool isActive;
  final List<CustomerAddressModel> addresses;
  final String createdAt;
  final String updatedAt;

  const CustomerModel({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    this.defaultAddressId,
    this.totalOrders = 0,
    this.totalSpent = 0,
    this.lastOrderDate,
    this.notes,
    this.isActive = true,
    this.addresses = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Customer toEntity() {
    return Customer(
      id: id,
      fullName: fullName,
      phone: phone,
      email: email,
      defaultAddressId: defaultAddressId,
      totalOrders: totalOrders,
      totalSpent: totalSpent,
      lastOrderDate:
          lastOrderDate != null ? DateTime.tryParse(lastOrderDate!) : null,
      notes: notes,
      isActive: isActive,
      addresses: addresses.map((a) => a.toEntity()).toList(),
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    double parseDecimal(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    final addressesJson = (json['addresses'] as List<dynamic>?) ?? const [];

    return CustomerModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      defaultAddressId: json['default_address_id'] as String?,
      totalOrders: (json['total_orders'] as num?)?.toInt() ?? 0,
      totalSpent: parseDecimal(json['total_spent']),
      lastOrderDate: json['last_order_date'] as String?,
      notes: json['notes'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      addresses: addressesJson
          .map((a) => CustomerAddressModel.fromJson(a as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }
}
