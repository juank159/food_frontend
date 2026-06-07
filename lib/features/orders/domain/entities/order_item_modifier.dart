import 'package:equatable/equatable.dart';
import '../../../../core/config/constants/modifier_enums.dart';

/// Order Item Modifier Entity
/// Representa un modificador aplicado a un ítem de orden específico
class OrderItemModifier extends Equatable {
  /// ID único del modificador aplicado
  final String id;

  /// ID del order item al que pertenece
  final String orderItemId;

  /// ID del modificador original
  final String modifierId;

  /// Nombre del modificador (desnormalizado para visualización)
  final String modifierName;

  /// Tipo de modificador
  final ModifierType type;

  /// Cantidad del modificador aplicado
  final int quantity;

  /// Precio unitario del modificador
  final double unitPrice;

  /// Subtotal del modificador (unitPrice * quantity)
  final double subtotal;

  const OrderItemModifier({
    required this.id,
    required this.orderItemId,
    required this.modifierId,
    required this.modifierName,
    required this.type,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  /// Verifica si el modificador tiene costo
  bool get hasCost => unitPrice > 0;

  /// Verifica si es una remoción
  bool get isRemoval => type == ModifierType.removal;

  /// Verifica si es una adición
  bool get isAddition => type == ModifierType.addition;

  /// Verifica si es una sustitución
  bool get isSubstitution => type == ModifierType.substitution;

  /// Obtiene el texto descriptivo del modificador
  String get displayText {
    final quantityText = quantity > 1 ? '$quantity x ' : '';
    return '$quantityText$modifierName';
  }

  /// Obtiene el texto del precio
  String get priceText {
    if (unitPrice == 0) return '';
    if (quantity > 1) {
      return '+\$$unitPrice c/u';
    }
    return '+\$$unitPrice';
  }

  @override
  List<Object?> get props => [
        id,
        orderItemId,
        modifierId,
        modifierName,
        type,
        quantity,
        unitPrice,
        subtotal,
      ];

  @override
  String toString() {
    return 'OrderItemModifier(id: $id, name: $modifierName, type: ${type.value}, qty: $quantity, price: $unitPrice)';
  }
}
