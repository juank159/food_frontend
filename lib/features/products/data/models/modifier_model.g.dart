// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'modifier_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ModifierModel _$ModifierModelFromJson(Map<String, dynamic> json) =>
    ModifierModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      modifierType: json['modifier_type'] as String,
      price: JsonParsers.parseDouble(json['price']),
      maxQuantity: (json['max_quantity'] as num?)?.toInt(),
      isAvailable: json['is_available'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$ModifierModelToJson(ModifierModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'modifier_type': instance.modifierType,
      'price': instance.price,
      'max_quantity': instance.maxQuantity,
      'is_available': instance.isAvailable,
      'sort_order': instance.sortOrder,
    };
