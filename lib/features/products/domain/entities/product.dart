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
  /// Costo unitario del producto (lo que le cuesta al negocio).
  /// `null` cuando el dueño aún no lo cargó. Se usa para `profitMargin`
  /// y para reportar utilidad real (revenue − cost × totalSold).
  final double? cost;
  /// `true` si el producto va a cocina/barra antes de entregarse.
  /// `false` para productos directos (botellas, snacks empacados):
  /// estos NO aparecen en la comanda y, si todo el ticket es así, no
  /// se imprime comanda en absoluto.
  final bool requiresPreparation;
  final int preparationTime; // en minutos
  final String? imageUrl;
  final String? sku;
  final String? barcode;
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

  /// Precio propio en la sede del dispositivo (`null` = el del catálogo).
  /// [basePrice]/[isAvailable] son SIEMPRE los del catálogo (lo que se
  /// edita en Productos); para vender usar [effectivePrice]/[availableHere].
  final double? branchPrice;

  /// `false` = apagado en la sede del dispositivo (`null` = como el catálogo).
  final bool? branchAvailable;

  /// Precio base con el que se vende en ESTA sede.
  double get effectivePrice => branchPrice ?? basePrice;

  /// ¿Se ofrece en ESTA sede?
  bool get availableHere => isAvailable && branchAvailable != false;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.basePrice,
    this.cost,
    this.requiresPreparation = true,
    required this.preparationTime,
    this.imageUrl,
    this.sku,
    this.barcode,
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
    this.branchPrice,
    this.branchAvailable,
  });

  Product copyWith({
    String? name,
    String? description,
    double? basePrice,
    double? cost,
    bool? requiresPreparation,
    int? preparationTime,
    String? imageUrl,
    String? sku,
    String? barcode,
    bool? isAvailable,
    List<String>? tags,
    List<String>? allergens,
    Map<String, dynamic>? nutritionalInfo,
    bool? trackInventory,
    int? currentStock,
    int? minStockAlert,
    int? totalSold,
    double? totalRevenue,
    String? categoryId,
    DateTime? updatedAt,
    List<ModifierGroup>? modifierGroups,
    List<ProductVariant>? variants,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      basePrice: basePrice ?? this.basePrice,
      cost: cost ?? this.cost,
      requiresPreparation: requiresPreparation ?? this.requiresPreparation,
      preparationTime: preparationTime ?? this.preparationTime,
      imageUrl: imageUrl ?? this.imageUrl,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      isAvailable: isAvailable ?? this.isAvailable,
      tags: tags ?? this.tags,
      allergens: allergens ?? this.allergens,
      nutritionalInfo: nutritionalInfo ?? this.nutritionalInfo,
      trackInventory: trackInventory ?? this.trackInventory,
      currentStock: currentStock ?? this.currentStock,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      totalSold: totalSold ?? this.totalSold,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      modifierGroups: modifierGroups ?? this.modifierGroups,
      variants: variants ?? this.variants,
      branchPrice: branchPrice,
      branchAvailable: branchAvailable,
    );
  }

  /// Margen porcentual: `(basePrice - cost) / basePrice × 100`.
  /// `null` cuando falta cost o basePrice ≤ 0 (no se puede calcular).
  double? get profitMargin {
    if (cost == null || basePrice <= 0) return null;
    return ((basePrice - cost!) / basePrice) * 100;
  }

  /// Ganancia por unidad vendida: `basePrice - cost`. `null` si falta cost.
  double? get profitPerUnit {
    if (cost == null) return null;
    return basePrice - cost!;
  }

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
        cost,
        requiresPreparation,
        preparationTime,
        imageUrl,
        sku,
        barcode,
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
        branchPrice,
        branchAvailable,
      ];
}
