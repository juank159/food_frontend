import 'package:equatable/equatable.dart';

/// Category Entity
/// Entidad de dominio para categorías de productos
class Category extends Equatable {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final String? color;
  final String? icon;
  final bool isActive;
  final int displayOrder;
  final String? parentId;
  final List<Category> children;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Category({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    this.color,
    this.icon,
    required this.isActive,
    required this.displayOrder,
    this.parentId,
    this.children = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Verifica si es una categoría raíz (sin padre)
  bool get isRootCategory => parentId == null;

  /// Verifica si tiene subcategorías
  bool get hasChildren => children.isNotEmpty;

  /// Obtiene el nivel de profundidad en el árbol
  int get level => parentId == null ? 0 : 1;

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        imageUrl,
        color,
        icon,
        isActive,
        displayOrder,
        parentId,
        children,
        createdAt,
        updatedAt,
      ];

  /// Copia la entidad con cambios
  Category copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? color,
    String? icon,
    bool? isActive,
    int? displayOrder,
    String? parentId,
    List<Category>? children,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      isActive: isActive ?? this.isActive,
      displayOrder: displayOrder ?? this.displayOrder,
      parentId: parentId ?? this.parentId,
      children: children ?? this.children,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
