import 'package:equatable/equatable.dart';
import 'customer_address.dart';

/// Customer Entity
///
/// Entidad de dominio para clientes registrados (delivery, takeaway, walk-in
/// con cuenta). El backend mantiene contadores agregados (`totalOrders`,
/// `totalSpent`, `lastOrderDate`) que se actualizan al cerrar una orden.
class Customer extends Equatable {
  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final String? defaultAddressId;
  final int totalOrders;
  final double totalSpent;
  final DateTime? lastOrderDate;
  final String? notes;
  final bool isActive;
  final List<CustomerAddress> addresses;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Customer({
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

  /// Iniciales para el avatar (máx 2 letras).
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// Indica si el cliente fue creado este mes (para KPI "nuevos").
  bool get isNewThisMonth {
    final now = DateTime.now();
    return createdAt.year == now.year && createdAt.month == now.month;
  }

  /// Indica si tiene actividad reciente (orden en los últimos 30 días).
  bool get hasRecentActivity {
    if (lastOrderDate == null) return false;
    return DateTime.now().difference(lastOrderDate!).inDays <= 30;
  }

  Customer copyWith({
    String? id,
    String? fullName,
    String? phone,
    String? email,
    String? defaultAddressId,
    int? totalOrders,
    double? totalSpent,
    DateTime? lastOrderDate,
    String? notes,
    bool? isActive,
    List<CustomerAddress>? addresses,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      defaultAddressId: defaultAddressId ?? this.defaultAddressId,
      totalOrders: totalOrders ?? this.totalOrders,
      totalSpent: totalSpent ?? this.totalSpent,
      lastOrderDate: lastOrderDate ?? this.lastOrderDate,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      addresses: addresses ?? this.addresses,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        fullName,
        phone,
        email,
        defaultAddressId,
        totalOrders,
        totalSpent,
        lastOrderDate,
        notes,
        isActive,
        addresses,
        createdAt,
        updatedAt,
      ];
}
