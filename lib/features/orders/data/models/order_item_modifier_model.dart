import 'package:json_annotation/json_annotation.dart';
import '../../../../core/config/constants/modifier_enums.dart';
import '../../domain/entities/order_item_modifier.dart';
import '../../../../core/utils/json_parsers.dart';

part 'order_item_modifier_model.g.dart';

/// Order Item Modifier Model
/// Modelo de datos para modificadores aplicados a ítems de orden
@JsonSerializable()
class OrderItemModifierModel {
  final String id;

  @JsonKey(name: 'order_item_id')
  final String orderItemId;

  @JsonKey(name: 'modifier_id')
  final String modifierId;

  @JsonKey(name: 'modifier_name')
  final String? modifierName;

  @JsonKey(name: 'modifier_type')
  final String modifierType;

  final int quantity;

  @JsonKey(name: 'unit_price', fromJson: JsonParsers.parseDouble)
  final double unitPrice;

  @JsonKey(fromJson: JsonParsers.parseDouble)
  final double subtotal;

  /// Objeto anidado del modificador (opcional, viene del backend)
  final ModifierNestedModel? modifier;

  const OrderItemModifierModel({
    required this.id,
    required this.orderItemId,
    required this.modifierId,
    this.modifierName,
    required this.modifierType,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.modifier,
  });

  /// Crear desde JSON
  factory OrderItemModifierModel.fromJson(Map<String, dynamic> json) =>
      _$OrderItemModifierModelFromJson(json);

  /// Convertir a JSON
  Map<String, dynamic> toJson() => _$OrderItemModifierModelToJson(this);

  /// Convertir a Entity
  OrderItemModifier toEntity() {
    // Usar el nombre del modifier anidado si está disponible
    final name = modifier?.name ?? modifierName ?? 'Modificador';

    return OrderItemModifier(
      id: id,
      orderItemId: orderItemId,
      modifierId: modifierId,
      modifierName: name,
      type: ModifierType.fromString(modifierType),
      quantity: quantity,
      unitPrice: unitPrice,
      subtotal: subtotal,
    );
  }

  /// Crear desde Entity (para enviar al backend al crear orden)
  factory OrderItemModifierModel.fromEntity(OrderItemModifier entity) {
    return OrderItemModifierModel(
      id: entity.id,
      orderItemId: entity.orderItemId,
      modifierId: entity.modifierId,
      modifierName: entity.modifierName,
      modifierType: entity.type.value,
      quantity: entity.quantity,
      unitPrice: entity.unitPrice,
      subtotal: entity.subtotal,
    );
  }
}

/// Modifier Nested Model
/// Modelo para el objeto anidado de modifier que viene del backend
@JsonSerializable()
class ModifierNestedModel {
  final String name;

  @JsonKey(name: 'modifier_type')
  final String modifierType;

  const ModifierNestedModel({
    required this.name,
    required this.modifierType,
  });

  factory ModifierNestedModel.fromJson(Map<String, dynamic> json) =>
      _$ModifierNestedModelFromJson(json);

  Map<String, dynamic> toJson() => _$ModifierNestedModelToJson(this);
}
