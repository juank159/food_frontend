import 'package:equatable/equatable.dart';
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
    required this.createdAt,
    required this.updatedAt,
  });

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
