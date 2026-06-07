import 'package:equatable/equatable.dart';

/// Razón del movimiento de stock — espeja el enum del backend
/// (`InventoryMovementReason`).
enum InventoryMovementReason {
  adjustment,
  orderConsume,
  orderRestore,
  purchase,
  waste;

  static InventoryMovementReason fromCode(String code) {
    switch (code) {
      case 'adjustment':
        return InventoryMovementReason.adjustment;
      case 'order_consume':
        return InventoryMovementReason.orderConsume;
      case 'order_restore':
        return InventoryMovementReason.orderRestore;
      case 'purchase':
        return InventoryMovementReason.purchase;
      case 'waste':
        return InventoryMovementReason.waste;
    }
    return InventoryMovementReason.adjustment;
  }

  String get label {
    switch (this) {
      case InventoryMovementReason.adjustment:
        return 'Ajuste manual';
      case InventoryMovementReason.orderConsume:
        return 'Consumo por orden';
      case InventoryMovementReason.orderRestore:
        return 'Devolución por cancelación';
      case InventoryMovementReason.purchase:
        return 'Ingreso de mercancía';
      case InventoryMovementReason.waste:
        return 'Merma';
    }
  }
}

/// Movimiento individual de stock — fila inmutable del histórico.
class InventoryMovement extends Equatable {
  final String id;
  final String productId;
  final int delta;
  final int stockAfter;
  final InventoryMovementReason reason;
  final String? userId;
  final String? userName;
  final String? orderId;
  final String? notes;
  final DateTime createdAt;

  const InventoryMovement({
    required this.id,
    required this.productId,
    required this.delta,
    required this.stockAfter,
    required this.reason,
    this.userId,
    this.userName,
    this.orderId,
    this.notes,
    required this.createdAt,
  });

  bool get isPositive => delta > 0;
  bool get isNegative => delta < 0;

  @override
  List<Object?> get props => [
        id,
        productId,
        delta,
        stockAfter,
        reason,
        userId,
        userName,
        orderId,
        notes,
        createdAt,
      ];
}
