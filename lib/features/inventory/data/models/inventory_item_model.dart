import '../../domain/entities/inventory_item.dart';
import '../../../../core/utils/json_parsers.dart';
import 'package:json_annotation/json_annotation.dart';

/// Inventory Item Model
///
/// Mapea la respuesta del backend (`Product`) a la proyección de
/// inventario. Los productos vienen del endpoint `GET /products`, que
/// puede devolver lista plana o `{ data: [...] }`.
///
/// Sólo retenemos los campos que el módulo de inventario necesita
/// (id, nombre, SKU, stock, umbral, flags). El resto del payload se
/// descarta porque inflarlo a un `Product` completo requeriría duplicar
/// el parsing de variantes/modificadores y no aporta valor acá.
class InventoryItemModel {
  final String id;
  final String name;
  final String? sku;
  final int? currentStock;
  final int? minStockAlert;
  final bool trackInventory;
  final bool isAvailable;
  final String? categoryName;
  @JsonKey(fromJson: JsonParsers.parseNullableDouble)
  final double? basePrice;

  InventoryItemModel({
    required this.id,
    required this.name,
    this.sku,
    this.currentStock,
    this.minStockAlert,
    required this.trackInventory,
    required this.isAvailable,
    this.categoryName,
    this.basePrice,
  });

  factory InventoryItemModel.fromJson(Map<String, dynamic> json) {
    return InventoryItemModel(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      sku: json['sku'] as String?,
      currentStock: _parseInt(json['current_stock']),
      minStockAlert: _parseInt(json['min_stock_alert']),
      trackInventory: json['track_inventory'] as bool? ?? false,
      isAvailable: json['is_available'] as bool? ?? true,
      categoryName: _parseCategoryName(json['category']),
      basePrice: _parseDouble(json['base_price']),
    );
  }

  InventoryItem toEntity() => InventoryItem(
        id: id,
        name: name,
        sku: sku,
        currentStock: currentStock,
        minStockAlert: minStockAlert,
        trackInventory: trackInventory,
        isAvailable: isAvailable,
        categoryName: categoryName,
        basePrice: basePrice,
      );

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Extrae el nombre de categoría desde el payload del backend. Algunos
  /// endpoints embeben el objeto `category: { id, name, ... }`, otros sólo
  /// mandan `category_id`. Si no podemos resolverlo lo devolvemos null y
  /// el detalle muestra "—".
  static String? _parseCategoryName(dynamic value) {
    if (value is Map) {
      final name = value['name'];
      if (name is String && name.isNotEmpty) return name;
    }
    return null;
  }
}
