import 'package:equatable/equatable.dart';
import '../../../products/domain/entities/product.dart';

/// Inventory Report Entity
///
/// Resumen del estado de stock de los productos trackeados. Se calcula
/// 100% en el cliente a partir de `GET /products?is_available=true` —
/// el backend no expone un endpoint dedicado de reporte de inventario,
/// pero los productos ya traen los campos necesarios (`current_stock`,
/// `min_stock_alert`, `track_inventory`).
class InventoryReport extends Equatable {
  /// Productos trackeados (con `track_inventory: true`).
  final List<Product> trackedProducts;

  const InventoryReport({this.trackedProducts = const []});

  factory InventoryReport.empty() =>
      const InventoryReport(trackedProducts: []);

  /// Cantidad total de productos con seguimiento de stock.
  int get totalTracked => trackedProducts.length;

  /// Productos con stock OK (no bajo, no agotado).
  int get inStockCount =>
      trackedProducts.where((p) => !p.isLowStock && !p.isOutOfStock).length;

  /// Productos cuyo stock cayó por debajo del umbral (incluye agotados).
  int get lowStockCount =>
      trackedProducts.where((p) => p.isLowStock).length;

  /// Productos completamente sin stock.
  int get outOfStockCount =>
      trackedProducts.where((p) => p.isOutOfStock).length;

  /// Productos con stock bajo o agotado, ordenados con los agotados
  /// primero y luego por menor stock — son los que el dueño tiene que
  /// ver primero al abrir el reporte.
  List<Product> get criticalProducts {
    final critical = trackedProducts
        .where((p) => p.isLowStock || p.isOutOfStock)
        .toList()
      ..sort((a, b) {
        if (a.isOutOfStock && !b.isOutOfStock) return -1;
        if (!a.isOutOfStock && b.isOutOfStock) return 1;
        final aStock = a.currentStock ?? 0;
        final bStock = b.currentStock ?? 0;
        return aStock.compareTo(bStock);
      });
    return critical;
  }

  /// Listado completo a mostrar: críticos arriba, resto del trackeo abajo
  /// ordenado por stock ascendente.
  List<Product> get sortedProducts {
    final list = [...trackedProducts]..sort((a, b) {
        // Agotados primero, luego stock bajo, luego ok.
        int rank(Product p) {
          if (p.isOutOfStock) return 0;
          if (p.isLowStock) return 1;
          return 2;
        }

        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        final aStock = a.currentStock ?? 0;
        final bStock = b.currentStock ?? 0;
        return aStock.compareTo(bStock);
      });
    return list;
  }

  @override
  List<Object?> get props => [trackedProducts];
}
