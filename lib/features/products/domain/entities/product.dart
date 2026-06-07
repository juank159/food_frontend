import 'package:equatable/equatable.dart';
import 'modifier_group.dart';
import 'product_variant.dart';

/// Product Entity (Domain Layer)
/// Representa un producto del menú en el dominio
class Product extends Equatable {
  final String id;
  final String name;
  final String description;
  final double basePrice;
  final int preparationTime; // en minutos
  final String? imageUrl;
  final String? sku;
  final bool isAvailable;
  final List<String> tags;
  final List<String> allergens;
  final Map<String, dynamic>? nutritionalInfo;
  final bool trackInventory;
  final int? currentStock;
  final int? minStockAlert;
  final int totalSold;
  final double totalRevenue;
  final String categoryId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ModifierGroup> modifierGroups;
  final List<ProductVariant> variants;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.basePrice,
    required this.preparationTime,
    this.imageUrl,
    this.sku,
    required this.isAvailable,
    required this.tags,
    required this.allergens,
    this.nutritionalInfo,
    required this.trackInventory,
    this.currentStock,
    this.minStockAlert,
    required this.totalSold,
    required this.totalRevenue,
    required this.categoryId,
    required this.createdAt,
    required this.updatedAt,
    this.modifierGroups = const [],
    this.variants = const [],
  });

  /// Verifica si el producto tiene stock bajo
  bool get isLowStock {
    if (!trackInventory || currentStock == null || minStockAlert == null) {
      return false;
    }
    return currentStock! <= minStockAlert!;
  }

  /// Verifica si el producto está agotado
  bool get isOutOfStock {
    if (!trackInventory || currentStock == null) {
      return false;
    }
    return currentStock! <= 0;
  }

  /// Verifica si el producto tiene grupos de modificadores
  bool get hasModifiers => modifierGroups.isNotEmpty;

  /// Obtiene el número de grupos de modificadores activos
  int get activeModifierGroupsCount =>
      modifierGroups.where((g) => g.isActive).length;

  /// Verifica si el producto tiene variantes
  bool get hasVariants => variants.isNotEmpty;

  /// Obtiene la variante por defecto
  ProductVariant? get defaultVariant =>
      variants.where((v) => v.isDefault && v.isAvailable).firstOrNull;

  /// Obtiene solo las variantes disponibles
  List<ProductVariant> get availableVariants =>
      variants.where((v) => v.isAvailable).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  /// Calcula el precio mínimo considerando variantes
  double get minPrice {
    if (!hasVariants) return basePrice;
    final prices = availableVariants.map((v) => v.calculateFinalPrice(basePrice));
    return prices.isEmpty ? basePrice : prices.reduce((a, b) => a < b ? a : b);
  }

  /// Calcula el precio máximo considerando variantes
  double get maxPrice {
    if (!hasVariants) return basePrice;
    final prices = availableVariants.map((v) => v.calculateFinalPrice(basePrice));
    return prices.isEmpty ? basePrice : prices.reduce((a, b) => a > b ? a : b);
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        basePrice,
        preparationTime,
        imageUrl,
        sku,
        isAvailable,
        tags,
        allergens,
        nutritionalInfo,
        trackInventory,
        currentStock,
        minStockAlert,
        totalSold,
        totalRevenue,
        categoryId,
        createdAt,
        updatedAt,
        modifierGroups,
        variants,
      ];
}
