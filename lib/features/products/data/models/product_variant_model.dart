import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/product_variant.dart';
import '../../../../core/utils/json_parsers.dart';

part 'product_variant_model.g.dart';

/// Converter para manejar price_modifier que puede venir como String o num
class PriceModifierConverter implements JsonConverter<double, dynamic> {
  const PriceModifierConverter();

  @override
  double fromJson(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  @override
  dynamic toJson(double value) => value;
}

/// Product Variant Model (Data Layer)
/// Maneja la serialización/deserialización JSON
@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class ProductVariantModel {
  final String id;
  final String productId;
  final String name;
  final String? description;

  @PriceModifierConverter()
  @JsonKey(fromJson: JsonParsers.parseDouble)
  final double priceModifier;

  final bool isDefault;
  final int? sortOrder;
  final bool isAvailable;
  final String? sku;
  /// Cantidad de cremas/bolas que exige la variante (null/0 = ninguna).
  final int? scoopCount;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  ProductVariantModel({
    required this.id,
    required this.productId,
    required this.name,
    this.description,
    required this.priceModifier,
    required this.isDefault,
    this.sortOrder,
    required this.isAvailable,
    this.sku,
    this.scoopCount,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// From JSON
  factory ProductVariantModel.fromJson(Map<String, dynamic> json) =>
      _$ProductVariantModelFromJson(json);

  /// To JSON
  Map<String, dynamic> toJson() => _$ProductVariantModelToJson(this);

  /// Convert Model to Entity
  ProductVariant toEntity() {
    return ProductVariant(
      id: id,
      productId: productId,
      name: name,
      description: description,
      priceModifier: priceModifier,
      isDefault: isDefault,
      sortOrder: sortOrder ?? 0,
      isAvailable: isAvailable,
      sku: sku,
      scoopCount: scoopCount,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }

  /// Convert Entity to Model
  factory ProductVariantModel.fromEntity(ProductVariant variant) {
    return ProductVariantModel(
      id: variant.id,
      productId: variant.productId,
      name: variant.name,
      description: variant.description,
      priceModifier: variant.priceModifier,
      isDefault: variant.isDefault,
      sortOrder: variant.sortOrder,
      isAvailable: variant.isAvailable,
      sku: variant.sku,
      scoopCount: variant.scoopCount,
      createdAt: variant.createdAt.toIso8601String(),
      updatedAt: variant.updatedAt.toIso8601String(),
      deletedAt: null,
    );
  }
}
