import 'package:equatable/equatable.dart';

/// Product Variant Entity (Domain Layer)
/// Representa una variante de producto (tamaños, tipos, etc.)
class ProductVariant extends Equatable {
  final String id;
  final String productId;
  final String name;
  final String? description;
  final double priceModifier; // Cantidad a sumar/restar del precio base
  final bool isDefault;
  final int sortOrder;
  final bool isAvailable;
  final String? sku;

  /// Cantidad de cremas/bolas que esta variante exige al venderse
  /// (ej. "2 bolas" → 2). null/0 = no pide cremas (no es heladería).
  final int? scoopCount;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductVariant({
    required this.id,
    required this.productId,
    required this.name,
    this.description,
    required this.priceModifier,
    required this.isDefault,
    required this.sortOrder,
    required this.isAvailable,
    this.sku,
    this.scoopCount,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Verifica si la variante tiene costo adicional
  bool get hasAdditionalCost => priceModifier > 0;

  /// Verifica si la variante tiene descuento
  bool get hasDiscount => priceModifier < 0;

  /// Verifica si la variante no modifica el precio
  bool get isNeutralPrice => priceModifier == 0;

  /// Calcula el precio final con la variante aplicada
  double calculateFinalPrice(double basePrice) {
    return basePrice + priceModifier;
  }

  @override
  List<Object?> get props => [
        id,
        productId,
        name,
        description,
        priceModifier,
        isDefault,
        sortOrder,
        isAvailable,
        sku,
        scoopCount,
        createdAt,
        updatedAt,
      ];
}
