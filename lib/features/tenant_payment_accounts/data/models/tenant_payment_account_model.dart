import '../../../../core/config/constants/order_enums.dart';
import '../../domain/entities/tenant_payment_account.dart';

class TenantPaymentAccountModel {
  final String id;
  final String name;
  final String category;
  final String? accountNumber;
  final String? accountHolder;
  final String? icon;
  final String? notes;
  final bool isActive;
  final int sortOrder;
  final String createdAt;
  final String updatedAt;

  const TenantPaymentAccountModel({
    required this.id,
    required this.name,
    required this.category,
    this.accountNumber,
    this.accountHolder,
    this.icon,
    this.notes,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TenantPaymentAccountModel.fromJson(Map<String, dynamic> json) {
    return TenantPaymentAccountModel(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'cash',
      accountNumber: json['account_number'] as String?,
      accountHolder: json['account_holder'] as String?,
      icon: json['icon'] as String?,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  TenantPaymentAccount toEntity() {
    return TenantPaymentAccount(
      id: id,
      name: name,
      category: PaymentMethod.fromString(category),
      accountNumber: accountNumber,
      accountHolder: accountHolder,
      icon: icon,
      notes: notes,
      isActive: isActive,
      sortOrder: sortOrder,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }
}
