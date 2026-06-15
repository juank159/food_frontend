// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_variant_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductVariantModel _$ProductVariantModelFromJson(Map<String, dynamic> json) =>
    ProductVariantModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      priceModifier: JsonParsers.parseDouble(json['price_modifier']),
      isDefault: json['is_default'] as bool,
      sortOrder: (json['sort_order'] as num?)?.toInt(),
      isAvailable: json['is_available'] as bool,
      sku: json['sku'] as String?,
      scoopCount: (json['scoop_count'] as num?)?.toInt(),
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      deletedAt: json['deleted_at'] as String?,
    );

Map<String, dynamic> _$ProductVariantModelToJson(
  ProductVariantModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'product_id': instance.productId,
  'name': instance.name,
  'description': instance.description,
  'price_modifier': const PriceModifierConverter().toJson(
    instance.priceModifier,
  ),
  'is_default': instance.isDefault,
  'sort_order': instance.sortOrder,
  'is_available': instance.isAvailable,
  'sku': instance.sku,
  'scoop_count': instance.scoopCount,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
  'deleted_at': instance.deletedAt,
};
