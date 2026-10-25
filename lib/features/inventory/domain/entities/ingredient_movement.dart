import 'package:flutter/material.dart';
import '../../../../core/config/theme/app_colors.dart';

/// Motivo de un movimiento — coincide con `IngredientMovementReason`
/// del backend.
enum MovementReason {
  sale('sale', 'Venta', Icons.point_of_sale, AppColors.info),
  saleReturn('sale_return', 'Devolución', Icons.undo, AppColors.info),
  purchase('purchase', 'Compra', Icons.local_shipping_outlined, AppColors.success),
  waste('waste', 'Merma', Icons.delete_sweep_outlined, AppColors.error),
  adjustment('adjustment', 'Ajuste', Icons.tune, AppColors.warning),
  count('count', 'Conteo', Icons.fact_check_outlined, AppColors.primary),
  initial('initial', 'Stock inicial', Icons.flag_outlined, AppColors.textSecondary);

  final String code;
  final String label;
  final IconData icon;
  final Color color;
  const MovementReason(this.code, this.label, this.icon, this.color);

  static MovementReason fromCode(String? code) => MovementReason.values
      .firstWhere((r) => r.code == code, orElse: () => MovementReason.adjustment);
}

class IngredientMovement {
  final String id;
  final String ingredientId;
  final double delta;
  final double stockAfter;
  final MovementReason reason;
  final double? unitCost;
  final String? userName;
  final String? orderId;
  final String? reference;
  final String? notes;
  final DateTime createdAt;

  /// Hecho sin internet, todavía en la cola.
  final bool pendingSync;

  const IngredientMovement({
    required this.id,
    required this.ingredientId,
    required this.delta,
    required this.stockAfter,
    required this.reason,
    this.unitCost,
    this.userName,
    this.orderId,
    this.reference,
    this.notes,
    required this.createdAt,
    this.pendingSync = false,
  });

  static double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  factory IngredientMovement.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return IngredientMovement(
      id: json['id'] as String,
      ingredientId: json['ingredient_id'] as String,
      delta: _num(json['delta']),
      stockAfter: _num(json['stock_after']),
      reason: MovementReason.fromCode(json['reason'] as String?),
      unitCost: json['unit_cost'] == null ? null : _num(json['unit_cost']),
      userName: user is Map ? user['full_name'] as String? : null,
      orderId: json['order_id'] as String?,
      reference: json['reference'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ingredient_id': ingredientId,
        'delta': delta,
        'stock_after': stockAfter,
        'reason': reason.code,
        'unit_cost': unitCost,
        'user': userName == null ? null : {'full_name': userName},
        'order_id': orderId,
        'reference': reference,
        'notes': notes,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}
