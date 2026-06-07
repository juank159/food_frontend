//lib features/tab_sessions/data/models/tab_session_model.dart

import '../../domain/entities/tab_session.dart';

/// Modelo de transferencia. Hace fromJson tolerante:
///   - Decimals como String (Postgres) o num.
///   - Campos anidados como `opened_by_user.full_name`, `customer.full_name`.
///   - Lista `orders` opcional (puede no venir en listados).
class TabSessionModel {
  final String id;
  final String? tableId;
  final String? tableElementId;
  final String? tableName;
  final String? customerId;
  final String? customerName;
  final String openedBy;
  final String? openedByName;
  final String openedAt;
  final String? closedBy;
  final String? closedByName;
  final String? closedAt;
  final String status;
  final int? partySize;
  final String? notes;
  final int totalOrders;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double tipAmount;
  final double deliveryFee;
  final double totalAmount;
  final double paidAmount;
  final double balance;
  final List<Map<String, dynamic>> orders;

  const TabSessionModel({
    required this.id,
    this.tableId,
    this.tableElementId,
    this.tableName,
    this.customerId,
    this.customerName,
    required this.openedBy,
    this.openedByName,
    required this.openedAt,
    this.closedBy,
    this.closedByName,
    this.closedAt,
    required this.status,
    this.partySize,
    this.notes,
    required this.totalOrders,
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.tipAmount,
    required this.deliveryFee,
    required this.totalAmount,
    required this.paidAmount,
    required this.balance,
    required this.orders,
  });

  factory TabSessionModel.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    // El backend a veces devuelve los FKs como string UUID (cuando no
    // se carga la relación) y a veces como objeto anidado (cuando
    // TypeORM expande la relación al guardar — caso del endpoint
    // `close` donde el `manager.save` devuelve la entity con relations
    // ya pegadas).
    //
    // Aceptamos ambos casos: si es String lo devolvemos; si es Map
    // sacamos el `id`. Sin esto, `as String?` revienta en runtime
    // con un TypeError porque _Map<String,dynamic> no castea a String.
    String? parseIdOrObject(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      if (value is Map<String, dynamic>) {
        final id = value['id'];
        return id is String ? id : null;
      }
      return null;
    }

    String? parseNameField(dynamic flatName, dynamic userObject) {
      if (flatName is String && flatName.isNotEmpty) return flatName;
      if (userObject is Map<String, dynamic>) {
        final n = userObject['full_name'];
        return n is String ? n : null;
      }
      return null;
    }

    final openedByUser = json['opened_by_user'] as Map<String, dynamic>?;
    final closedByUser = json['closed_by_user'] as Map<String, dynamic>?;
    final customer = json['customer'] as Map<String, dynamic>?;
    final ordersRaw = json['orders'] as List<dynamic>? ?? const [];

    return TabSessionModel(
      id: json['id'] as String,
      tableId: parseIdOrObject(json['table_id']),
      tableElementId: json['table_element_id'] as String?,
      tableName: json['table_name'] as String?,
      customerId: parseIdOrObject(json['customer_id']),
      customerName: parseNameField(json['customer_name'], customer),
      openedBy: parseIdOrObject(json['opened_by']) ?? '',
      openedByName: parseNameField(json['opened_by_name'], openedByUser),
      openedAt: json['opened_at'] as String,
      closedBy: parseIdOrObject(json['closed_by']),
      closedByName: parseNameField(json['closed_by_name'], closedByUser),
      closedAt: json['closed_at'] as String?,
      status: json['status'] as String? ?? 'open',
      partySize: (json['party_size'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      totalOrders: (json['total_orders'] as num?)?.toInt() ?? 0,
      subtotal: parseNum(json['subtotal']),
      taxAmount: parseNum(json['tax_amount']),
      discountAmount: parseNum(json['discount_amount']),
      tipAmount: parseNum(json['tip_amount']),
      deliveryFee: parseNum(json['delivery_fee']),
      totalAmount: parseNum(json['total_amount']),
      paidAmount: parseNum(json['paid_amount']),
      balance: parseNum(json['balance']),
      orders: ordersRaw.whereType<Map<String, dynamic>>().toList(),
    );
  }

  TabSession toEntity() {
    return TabSession(
      id: id,
      tableId: tableId,
      tableElementId: tableElementId,
      tableName: tableName,
      customerId: customerId,
      customerName: customerName,
      openedBy: openedBy,
      openedByName: openedByName,
      openedAt: DateTime.parse(openedAt),
      closedBy: closedBy,
      closedByName: closedByName,
      closedAt: closedAt != null ? DateTime.parse(closedAt!) : null,
      status: TabSessionStatus.fromString(status),
      partySize: partySize,
      notes: notes,
      totalOrders: totalOrders,
      subtotal: subtotal,
      taxAmount: taxAmount,
      discountAmount: discountAmount,
      tipAmount: tipAmount,
      deliveryFee: deliveryFee,
      totalAmount: totalAmount,
      paidAmount: paidAmount,
      balance: balance,
      orders: orders,
    );
  }
}
