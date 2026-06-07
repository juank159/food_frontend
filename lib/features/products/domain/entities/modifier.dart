import 'package:equatable/equatable.dart';
import '../../../../core/config/constants/modifier_enums.dart';

/// Modifier Entity
/// Representa un modificador que se puede aplicar a un producto
/// Ejemplos: "Sin Cebolla", "Extra Queso", "Doble Carne"
class Modifier extends Equatable {
  /// ID único del modificador
  final String id;

  /// Nombre del modificador
  final String name;

  /// Descripción opcional del modificador
  final String? description;

  /// Tipo de modificador (addition, removal, substitution)
  final ModifierType type;

  /// Precio adicional del modificador (puede ser 0 para remociones)
  final double price;

  /// Cantidad máxima que se puede agregar (null = ilimitado)
  final int? maxQuantity;

  /// Indica si el modificador está disponible
  final bool isAvailable;

  /// Orden de visualización
  final int sortOrder;

  /// IDs de productos a los que aplica el modificador (mapping `applies_to.product_ids`)
  final List<String>? appliesToProducts;

  /// IDs de categorías a las que aplica el modificador (mapping `applies_to.category_ids`)
  final List<String>? appliesToCategories;

  const Modifier({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    required this.price,
    this.maxQuantity,
    this.isAvailable = true,
    this.sortOrder = 0,
    this.appliesToProducts,
    this.appliesToCategories,
  });

  /// Verifica si el modificador tiene costo adicional
  bool get hasAdditionalCost => price > 0;

  /// Verifica si el modificador es una remoción
  bool get isRemoval => type == ModifierType.removal;

  /// Verifica si el modificador es una adición
  bool get isAddition => type == ModifierType.addition;

  /// Verifica si el modificador es una sustitución
  bool get isSubstitution => type == ModifierType.substitution;

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        type,
        price,
        maxQuantity,
        isAvailable,
        sortOrder,
        appliesToProducts,
        appliesToCategories,
      ];

  @override
  String toString() {
    return 'Modifier(id: $id, name: $name, type: ${type.value}, price: $price)';
  }
}
