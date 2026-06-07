import 'package:equatable/equatable.dart';
import '../../../../core/config/constants/order_enums.dart';

/// Cuenta de pago concreta del tenant — Nequi, Daviplata, Bancolombia,
/// caja registradora, datáfono, etc. La `category` se mapea al enum
/// global `PaymentMethod` (cash / card / transfer / digital_wallet)
/// para que los reportes existentes sigan funcionando.
class TenantPaymentAccount extends Equatable {
  final String id;
  final String name;
  final PaymentMethod category;
  final String? accountNumber;
  final String? accountHolder;
  final String? icon;
  final String? notes;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TenantPaymentAccount({
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

  TenantPaymentAccount copyWith({
    String? name,
    PaymentMethod? category,
    String? accountNumber,
    String? accountHolder,
    String? icon,
    String? notes,
    bool? isActive,
    int? sortOrder,
  }) {
    return TenantPaymentAccount(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      accountNumber: accountNumber ?? this.accountNumber,
      accountHolder: accountHolder ?? this.accountHolder,
      icon: icon ?? this.icon,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        category,
        accountNumber,
        accountHolder,
        icon,
        notes,
        isActive,
        sortOrder,
        createdAt,
        updatedAt,
      ];
}
