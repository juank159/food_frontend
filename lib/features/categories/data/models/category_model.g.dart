// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CategoryModel _$CategoryModelFromJson(Map<String, dynamic> json) =>
    CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      color: json['color'] as String?,
      icon: json['icon'] as String?,
      isActive: json['is_active'] as bool,
      displayOrder: (json['sort_order'] as num?)?.toInt(),
      parentId: json['parent_category_id'] as String?,
      printsKitchen: json['prints_kitchen'] as bool? ?? true,
      children: (_readChildren(json, 'subcategories') as List<dynamic>?)
          ?.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );

Map<String, dynamic> _$CategoryModelToJson(CategoryModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'image_url': instance.imageUrl,
      'color': instance.color,
      'icon': instance.icon,
      'is_active': instance.isActive,
      'sort_order': instance.displayOrder,
      'parent_category_id': instance.parentId,
      'prints_kitchen': instance.printsKitchen,
      'subcategories': instance.children,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };
