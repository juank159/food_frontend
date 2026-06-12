import 'package:equatable/equatable.dart';

import '../../../../core/config/constants/order_enums.dart';
import 'order_item_modifier.dart';

/// Order Item Entity
/// Entidad de dominio para los items de una orden
class OrderItem extends Equatable {
  final String id;
  final String orderId;
  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;
  final double subtotal;
  final String? specialInstructions;
  final Map<String, dynamic>? customizations;
  final List<OrderItemModifier> modifiers;
  /// Estado individual del item. Cocina lo lleva de `pending` → `ready`;
  /// el mesero lo lleva de `ready` → `delivered`.
  final OrderStatus status;
  /// `true` cuando el producto va a cocina/barra. Si es `false`, el item
  /// nunca aparece en el KDS.
  final bool requiresPreparation;
  final DateTime? preparedAt;
  final DateTime? deliveredAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
    this.specialInstructions,
    this.customizations,
    this.modifiers = const [],
    this.status = OrderStatus.pending,
    this.requiresPreparation = true,
    this.preparedAt,
    this.deliveredAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// `true` si la cocina ya terminó el item (ready o más adelante).
  bool get isReady =>
      status == OrderStatus.ready ||
      status == OrderStatus.delivered ||
      status == OrderStatus.completed;

  /// `true` si el mesero ya lo bajó a la mesa.
  bool get isDelivered =>
      status == OrderStatus.delivered || status == OrderStatus.completed;

  /// Calcula el total del item
  double get total => subtotal;

  /// Verifica si tiene instrucciones especiales
  bool get hasSpecialInstructions =>
      specialInstructions != null && specialInstructions!.isNotEmpty;

  /// Verifica si tiene customizaciones
  bool get hasCustomizations =>
      customizations != null && customizations!.isNotEmpty;

  /// Verifica si tiene modificadores
  bool get hasModifiers => modifiers.isNotEmpty;

  /// Obtiene el total de modificadores
  double get modifiersTotal =>
      modifiers.fold<double>(0.0, (sum, mod) => sum + mod.subtotal);

  /// Obtiene los modificadores con costo
  List<OrderItemModifier> get paidModifiers =>
      modifiers.where((m) => m.hasCost).toList();

  /// Obtiene los modificadores sin costo (remociones)
  List<OrderItemModifier> get freeModifiers =>
      modifiers.where((m) => !m.hasCost).toList();

  @override
  List<Object?> get props => [
        id,
        orderId,
        productId,
        productName,
        unitPrice,
        quantity,
        subtotal,
        specialInstructions,
        customizations,
        modifiers,
        status,
        requiresPreparation,
        preparedAt,
        deliveredAt,
        createdAt,
        updatedAt,
      ];

  /// Copia la entidad con cambios
  OrderItem copyWith({
    String? id,
    String? orderId,
    String? productId,
    String? productName,
    double? unitPrice,
    int? quantity,
    double? subtotal,
    String? specialInstructions,
    Map<String, dynamic>? customizations,
    List<OrderItemModifier>? modifiers,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      subtotal: subtotal ?? this.subtotal,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      customizations: customizations ?? this.customizations,
      modifiers: modifiers ?? this.modifiers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
