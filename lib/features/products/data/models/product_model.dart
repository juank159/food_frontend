import 'package:flutter/foundation.dart';
import '../../domain/entities/product.dart';
import 'modifier_group_model.dart';
import 'product_variant_model.dart';
import '../../../../core/utils/json_parsers.dart';
import 'package:json_annotation/json_annotation.dart';

/// Product Model (Data Layer)
/// Maneja la serialización/deserialización JSON con parsing manual robusto
class ProductModel {
  final String id;
  final String name;
  final String description;
  @JsonKey(fromJson: JsonParsers.parseDouble)
  final double basePrice;
  /// Costo unitario (lo que le cuesta al negocio). Postgres lo manda
  /// como string decimal — usamos parser tolerante en `fromJson`.
  /// `null` cuando el dueño aún no lo cargó.
  final double? cost;
  /// `true` si el producto pasa por cocina/barra. Si es `false`, la
  /// línea no aparece en la comanda impresa y, si TODOS los items del
  /// ticket son así, no se imprime comanda en absoluto.
  final bool requiresPreparation;
  final int preparationTime;
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
  @JsonKey(fromJson: JsonParsers.parseDouble)
  final double totalRevenue;
  final int? sortOrder;
  final String categoryId;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final List<ModifierGroupModel> modifierGroups;
  final List<ProductVariantModel> variants;

  ProductModel({
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
    this.sortOrder,
    required this.categoryId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.modifierGroups = const [],
    this.variants = const [],
  });

  /// From JSON with robust error handling
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    try {
      // Handle category_id - can come as direct field or nested in category object
      String categoryId;
      if (json['category_id'] != null) {
        categoryId = json['category_id'] as String;
      } else if (json['category'] != null && json['category'] is Map) {
        categoryId = (json['category'] as Map<String, dynamic>)['id'] as String;
      } else {
        throw FormatException('Missing category_id in product');
      }

      // Parse modifier_groups
      List<ModifierGroupModel> parsedModifierGroups = [];
      if (json['modifier_groups'] != null && json['modifier_groups'] is List) {
        final groupsList = json['modifier_groups'] as List;
        parsedModifierGroups = groupsList
            .where((g) => g != null)
            .map((g) {
              try {
                return ModifierGroupModel.fromJson(g as Map<String, dynamic>);
              } catch (e) {
                // Log error pero no rompe todo el parsing
                debugPrint('Error parsing modifier group: $e');
                return null;
              }
            })
            .where((g) => g != null)
            .cast<ModifierGroupModel>()
            .toList();
      }

      // Parse variants
      List<ProductVariantModel> parsedVariants = [];
      if (json['variants'] != null && json['variants'] is List) {
        final variantsList = json['variants'] as List;
        parsedVariants = variantsList
            .where((v) => v != null)
            .map((v) {
              try {
                return ProductVariantModel.fromJson(v as Map<String, dynamic>);
              } catch (e) {
                // Log error pero no rompe todo el parsing
                debugPrint('Error parsing variant: $e');
                return null;
              }
            })
            .where((v) => v != null)
            .cast<ProductVariantModel>()
            .toList();
      }

      return ProductModel(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        basePrice: _parseDouble(json['base_price']),
        // `cost` puede no venir (productos viejos) o venir como string.
        // `_parseNullableDouble` distingue null real de 0 — un costo de
        // 0 es semánticamente distinto a "sin definir".
        cost: _parseNullableDouble(json['cost']),
        // `requires_preparation` default true por la columna del backend,
        // pero si el JSON viene sin el campo (response viejo cacheado),
        // mantenemos el default.
        requiresPreparation: json['requires_preparation'] as bool? ?? true,
        preparationTime: _parseInt(json['preparation_time']) ?? 0,
        imageUrl: json['image_url'] as String?,
        sku: json['sku'] as String?,
        barcode: json['barcode'] as String?,
        isAvailable: json['is_available'] as bool? ?? true,
        tags: _parseStringList(json['tags']),
        allergens: _parseStringList(json['allergens']),
        nutritionalInfo: json['nutritional_info'] as Map<String, dynamic>?,
        trackInventory: json['track_inventory'] as bool? ?? false,
        currentStock: _parseInt(json['current_stock']),
        minStockAlert: _parseInt(json['min_stock_alert']),
        totalSold: _parseInt(json['total_sold']) ?? 0,
        totalRevenue: _parseDouble(json['total_revenue']),
        sortOrder: _parseInt(json['sort_order']),
        categoryId: categoryId,
        createdAt: json['created_at'] as String,
        updatedAt: json['updated_at'] as String,
        deletedAt: json['deleted_at'] as String?,
        modifierGroups: parsedModifierGroups,
        variants: parsedVariants,
      );
    } catch (e, stackTrace) {
      throw FormatException('Error parsing ProductModel from JSON: $e\nJSON: $json\nStackTrace: $stackTrace');
    }
  }

  /// Helper method to parse double from various types
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Helper para parsear doubles que pueden ser null (distinto de 0).
  /// "Sin costo definido" ≠ "costo 0".
  static double? _parseNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      if (value.isEmpty) return null;
      return double.tryParse(value);
    }
    return null;
  }

  /// Helper method to parse int from various types
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Helper method to parse string list safely
  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  /// To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'base_price': basePrice,
      'cost': cost,
      'requires_preparation': requiresPreparation,
      'preparation_time': preparationTime,
      'image_url': imageUrl,
      'sku': sku,
      'barcode': barcode,
      'is_available': isAvailable,
      'tags': tags,
      'allergens': allergens,
      'nutritional_info': nutritionalInfo,
      'track_inventory': trackInventory,
      'current_stock': currentStock,
      'min_stock_alert': minStockAlert,
      'total_sold': totalSold,
      'total_revenue': totalRevenue,
      'sort_order': sortOrder,
      'category_id': categoryId,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
    };
  }

  /// Convert Model to Entity
  Product toEntity() {
    return Product(
      id: id,
      name: name,
      description: description,
      basePrice: basePrice,
      cost: cost,
      requiresPreparation: requiresPreparation,
      preparationTime: preparationTime,
      imageUrl: imageUrl,
      sku: sku,
      barcode: barcode,
      isAvailable: isAvailable,
      tags: tags,
      allergens: allergens,
      nutritionalInfo: nutritionalInfo,
      trackInventory: trackInventory,
      currentStock: currentStock,
      minStockAlert: minStockAlert,
      totalSold: totalSold,
      totalRevenue: totalRevenue,
      categoryId: categoryId,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
      modifierGroups: modifierGroups.map((g) => g.toEntity()).toList(),
      variants: variants.map((v) => v.toEntity()).toList(),
    );
  }

  /// Convert Entity to Model
  factory ProductModel.fromEntity(Product product) {
    return ProductModel(
      id: product.id,
      name: product.name,
      description: product.description,
      basePrice: product.basePrice,
      cost: product.cost,
      requiresPreparation: product.requiresPreparation,
      preparationTime: product.preparationTime,
      imageUrl: product.imageUrl,
      sku: product.sku,
      barcode: product.barcode,
      isAvailable: product.isAvailable,
      tags: product.tags,
      allergens: product.allergens,
      nutritionalInfo: product.nutritionalInfo,
      trackInventory: product.trackInventory,
      currentStock: product.currentStock,
      minStockAlert: product.minStockAlert,
      totalSold: product.totalSold,
      totalRevenue: product.totalRevenue,
      sortOrder: null,
      categoryId: product.categoryId,
      createdAt: product.createdAt.toIso8601String(),
      updatedAt: product.updatedAt.toIso8601String(),
      deletedAt: null,
      modifierGroups: product.modifierGroups.map((g) => ModifierGroupModel.fromEntity(g)).toList(),
      variants: product.variants.map((v) => ProductVariantModel.fromEntity(v)).toList(),
    );
  }
}
