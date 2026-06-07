// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_item_modifier_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderItemModifierModel _$OrderItemModifierModelFromJson(
  Map<String, dynamic> json,
) => OrderItemModifierModel(
  id: json['id'] as String,
  orderItemId: json['order_item_id'] as String,
  modifierId: json['modifier_id'] as String,
  modifierName: json['modifier_name'] as String?,
  modifierType: json['modifier_type'] as String,
  quantity: (json['quantity'] as num).toInt(),
  unitPrice: JsonParsers.parseDouble(json['unit_price']),
  subtotal: JsonParsers.parseDouble(json['subtotal']),
  modifier: json['modifier'] == null
      ? null
      : ModifierNestedModel.fromJson(json['modifier'] as Map<String, dynamic>),
);

Map<String, dynamic> _$OrderItemModifierModelToJson(
  OrderItemModifierModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'order_item_id': instance.orderItemId,
  'modifier_id': instance.modifierId,
  'modifier_name': instance.modifierName,
  'modifier_type': instance.modifierType,
  'quantity': instance.quantity,
  'unit_price': instance.unitPrice,
  'subtotal': instance.subtotal,
  'modifier': instance.modifier,
};

ModifierNestedModel _$ModifierNestedModelFromJson(Map<String, dynamic> json) =>
    ModifierNestedModel(
      name: json['name'] as String,
      modifierType: json['modifier_type'] as String,
    );

Map<String, dynamic> _$ModifierNestedModelToJson(
  ModifierNestedModel instance,
) => <String, dynamic>{
  'name': instance.name,
  'modifier_type': instance.modifierType,
};
