import 'package:equatable/equatable.dart';

/// Inventory Item Entity
///
/// Vista del módulo de inventario sobre un producto. El backend NO tiene
/// una entidad "InventoryItem" propia: usamos el `Product` con énfasis en
/// los campos de stock (`current_stock`, `min_stock_alert`,
/// `track_inventory`). Esta entidad es una proyección de eso.
class InventoryItem extends Equatable {
  /// ID del producto subyacente — necesario para enviar el `PATCH /products/:id`
  /// al ajustar stock.
  final String id;

  final String name;

  /// SKU del producto (puede ser null en datos viejos).
  final String? sku;

  /// Stock actual. Null cuando el producto no trackea inventario o
  /// cuando el backend nunca seteó el campo.
  final int? currentStock;

  /// Umbral configurado por el comercio. Null = sin alerta de stock bajo.
  final int? minStockAlert;

  /// `true` si este producto trackea inventario. Cuando es `false`, los
  /// indicadores de stock se ocultan (no aplican).
  final bool trackInventory;

  /// `true` si está disponible para venta (independiente del stock).
  final bool isAvailable;

  /// Nombre de la categoría asociada al producto. Null cuando el backend
  /// no la incluye en el payload de `GET /products` (no garantizamos que
  /// venga embebida — depende de la versión del API).
  final String? categoryName;

  /// Precio base del producto. Null cuando el backend no expone el campo
  /// en el item listado o cuando el producto está pendiente de pricing.
  final double? basePrice;

  const InventoryItem({
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

  /// Está agotado: trackea inventario y stock <= 0.
  bool get isOutOfStock {
    if (!trackInventory) return false;
    final s = currentStock ?? 0;
    return s <= 0;
  }

  /// Tiene stock bajo pero todavía no está agotado: trackea inventario,
  /// hay stock > 0, y stock <= minStockAlert.
  bool get isLowStock {
    if (!trackInventory) return false;
    final s = currentStock ?? 0;
    final min = minStockAlert ?? 0;
    if (s <= 0) return false;
    if (min <= 0) return false;
    return s <= min;
  }

  /// Tiene stock saludable: trackea, no está agotado ni bajo.
  bool get isHealthyStock {
    if (!trackInventory) return false;
    return !isOutOfStock && !isLowStock;
  }

  @override
  List<Object?> get props => [
        id,
        name,
        sku,
        currentStock,
        minStockAlert,
        trackInventory,
        isAvailable,
        categoryName,
        basePrice,
      ];
}
