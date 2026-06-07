// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'modifier_group_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ModifierGroupModel _$ModifierGroupModelFromJson(Map<String, dynamic> json) =>
    ModifierGroupModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      selectionType: json['selection_type'] as String,
      minSelections: (json['min_selections'] as num?)?.toInt() ?? 0,
      maxSelections: (json['max_selections'] as num?)?.toInt(),
      isRequired: json['is_required'] as bool? ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      modifiers:
          (json['modifiers'] as List<dynamic>?)
              ?.map((e) => ModifierModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ModifierGroupModelToJson(ModifierGroupModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'product_id': instance.productId,
      'name': instance.name,
      'description': instance.description,
      'selection_type': instance.selectionType,
      'min_selections': instance.minSelections,
      'max_selections': instance.maxSelections,
      'is_required': instance.isRequired,
      'sort_order': instance.sortOrder,
      'is_active': instance.isActive,
      'modifiers': instance.modifiers,
    };
