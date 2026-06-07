import 'package:json_annotation/json_annotation.dart';
import '../../../../core/config/constants/modifier_enums.dart';
import '../../domain/entities/modifier.dart';
import '../../../../core/utils/json_parsers.dart';

part 'modifier_model.g.dart';

/// Modifier Model
/// Modelo de datos para modificadores con serialización JSON
@JsonSerializable()
class ModifierModel {
  final String id;
  final String name;
  final String? description;

  @JsonKey(name: 'modifier_type')
  final String modifierType;

  @JsonKey(fromJson: JsonParsers.parseDouble)
  final double price;

  @JsonKey(name: 'max_quantity')
  final int? maxQuantity;

  @JsonKey(name: 'is_available')
  final bool isAvailable;

  @JsonKey(name: 'sort_order')
  final int sortOrder;

  /// IDs de productos a los que aplica (mapeado de `applies_to.product_ids`).
  /// Excluido de la serialización generada porque vive dentro del objeto
  /// anidado `applies_to`; lo poblamos manualmente en `fromJson` y en
  /// `toEntity`.
  @JsonKey(includeFromJson: false, includeToJson: false)
  final List<String>? appliesToProducts;

  /// IDs de categorías a las que aplica (mapeado de `applies_to.category_ids`).
  @JsonKey(includeFromJson: false, includeToJson: false)
  final List<String>? appliesToCategories;

  const ModifierModel({
    required this.id,
    required this.name,
    this.description,
    required this.modifierType,
    required this.price,
    this.maxQuantity,
    this.isAvailable = true,
    this.sortOrder = 0,
    this.appliesToProducts,
    this.appliesToCategories,
  });

  /// Crear desde JSON.
  ///
  /// Parseo robusto: el backend usa `numeric(10,2)` para `price` y TypeORM lo
  /// devuelve como `String` en muchas configuraciones (driver pg). Si dejamos
  /// el `as num` autogenerado se cae con `_TypeError`. Forzamos un cast
  /// tolerante a través de `_parseDouble` y delegamos el resto al generado.
  ///
  /// Adicionalmente, el backend serializa el campo `applies_to` como un
  /// objeto anidado `{ product_ids, category_ids }`. Lo extraemos a mano para
  /// exponerlo como `appliesToProducts` / `appliesToCategories`.
  factory ModifierModel.fromJson(Map<String, dynamic> json) {
    final normalized = <String, dynamic>{
      ...json,
      'price': _parseDouble(json['price']),
    };
    final base = _$ModifierModelFromJson(normalized);
    final appliesTo = json['applies_to'];
    return ModifierModel(
      id: base.id,
      name: base.name,
      description: base.description,
      modifierType: base.modifierType,
      price: base.price,
      maxQuantity: base.maxQuantity,
      isAvailable: base.isAvailable,
      sortOrder: base.sortOrder,
      appliesToProducts: _parseStringList(
        appliesTo is Map ? appliesTo['product_ids'] : null,
      ),
      appliesToCategories: _parseStringList(
        appliesTo is Map ? appliesTo['category_ids'] : null,
      ),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    if (value is num) return value.toDouble();
    return 0.0;
  }

  static List<String>? _parseStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return null;
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() => _$ModifierModelToJson(this);

  /// Convertir a Entity
  Modifier toEntity() {
    return Modifier(
      id: id,
      name: name,
      description: description,
      type: ModifierType.fromString(modifierType),
      price: price,
      maxQuantity: maxQuantity,
      isAvailable: isAvailable,
      sortOrder: sortOrder,
      appliesToProducts: appliesToProducts,
      appliesToCategories: appliesToCategories,
    );
  }

  /// Crear desde Entity
  factory ModifierModel.fromEntity(Modifier entity) {
    return ModifierModel(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      modifierType: entity.type.value,
      price: entity.price,
      maxQuantity: entity.maxQuantity,
      isAvailable: entity.isAvailable,
      sortOrder: entity.sortOrder,
      appliesToProducts: entity.appliesToProducts,
      appliesToCategories: entity.appliesToCategories,
    );
  }
}
