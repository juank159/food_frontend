import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/category.dart';

part 'category_model.g.dart';

/// Category Model
/// Modelo de datos para serialización JSON de categorías.
///
/// Mapeamos los campos al esquema real del backend:
///   - `parent_category_id` (entity column).
///   - `subcategories` (relación TypeORM) → exponemos como `children`
///     en la API local para mantener un nombre más natural.
///
/// `color` y `icon` no están en la entidad del backend hoy y vienen
/// vacíos. Se mantienen en el modelo para no romper el flujo existente
/// y poder activarlos cuando el backend los soporte.
@JsonSerializable()
class CategoryModel {
  final String id;
  final String name;
  // El backend tiene `description` como opcional; aceptamos null y lo
  // normalizamos a string vacío en `toEntity` para no propagar nullables.
  final String? description;
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  final String? color;
  final String? icon;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'sort_order')
  final int? displayOrder;
  @JsonKey(name: 'parent_category_id')
  final String? parentId;
  /// Si la categoría imprime comanda de cocina. Default `true`.
  @JsonKey(name: 'prints_kitchen')
  final bool printsKitchen;
  // El backend devuelve la relación como `subcategories` (TypeORM).
  // Aceptamos también `children` por si algún endpoint lo serializa así.
  @JsonKey(name: 'subcategories', readValue: _readChildren)
  final List<CategoryModel>? children;
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'updated_at')
  final String updatedAt;

  const CategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.color,
    this.icon,
    required this.isActive,
    this.displayOrder,
    this.parentId,
    this.printsKitchen = true,
    this.children,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convierte el modelo a entidad de dominio
  Category toEntity() {
    return Category(
      id: id,
      name: name,
      description: description ?? '',
      imageUrl: imageUrl,
      color: color,
      icon: icon,
      isActive: isActive,
      displayOrder: displayOrder ?? 0,
      parentId: parentId,
      printsKitchen: printsKitchen,
      children: children?.map((child) => child.toEntity()).toList() ?? const [],
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }

  /// Crea un modelo desde una entidad de dominio
  factory CategoryModel.fromEntity(Category category) {
    return CategoryModel(
      id: category.id,
      name: category.name,
      description: category.description,
      imageUrl: category.imageUrl,
      color: category.color,
      icon: category.icon,
      isActive: category.isActive,
      displayOrder: category.displayOrder,
      parentId: category.parentId,
      printsKitchen: category.printsKitchen,
      children: category.children
          .map((child) => CategoryModel.fromEntity(child))
          .toList(),
      createdAt: category.createdAt.toIso8601String(),
      updatedAt: category.updatedAt.toIso8601String(),
    );
  }

  /// Deserialización desde JSON
  factory CategoryModel.fromJson(Map<String, dynamic> json) =>
      _$CategoryModelFromJson(json);

  /// Serialización a JSON
  Map<String, dynamic> toJson() => _$CategoryModelToJson(this);
}

/// Lee `subcategories` o `children` del JSON, lo que esté disponible.
/// El backend usa `subcategories` (relación TypeORM) pero algunos
/// endpoints futuros pueden serializarlo como `children`.
Object? _readChildren(Map<dynamic, dynamic> json, String key) {
  return json['subcategories'] ?? json['children'];
}
