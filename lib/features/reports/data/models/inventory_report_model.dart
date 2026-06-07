import '../../../products/data/models/product_model.dart';
import '../../../products/domain/entities/product.dart';
import '../../domain/entities/inventory_report.dart';

/// Inventory Report Model
///
/// El reporte de inventario se compone client-side a partir de la lista
/// de productos devuelta por `GET /products`. Este model envuelve esa
/// lista cruda y la convierte en la entidad de dominio aplicando el
/// filtro de "track_inventory: true" — los productos sin seguimiento de
/// stock no aportan al reporte.
class InventoryReportModel {
  final List<ProductModel> products;

  InventoryReportModel({required this.products});

  /// Filtra los productos trackeados y los entrega como entidades de
  /// dominio listas para consumir por la UI.
  InventoryReport toEntity() {
    final tracked = products
        .map<Product>((m) => m.toEntity())
        .where((p) => p.trackInventory)
        .toList();
    return InventoryReport(trackedProducts: tracked);
  }
}
