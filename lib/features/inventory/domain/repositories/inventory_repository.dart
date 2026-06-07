import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/inventory_item.dart';
import '../entities/inventory_movement.dart';

/// Inventory Repository
///
/// Contrato del repositorio de inventario. Las dos operaciones que
/// importan son listar (`GET /products`) y ajustar stock
/// (`PATCH /products/:id`).
abstract class InventoryRepository {
  /// Obtiene el catálogo desde inventario. Cuando `onlyTracked` es true
  /// se filtran los items que no trackean inventario en el cliente
  /// (el backend no tiene query param para eso por ahora).
  Future<Either<Failure, List<InventoryItem>>> getInventory({
    bool onlyTracked = false,
  });

  /// Ajusta el stock de un producto. `currentStock` es el valor absoluto
  /// nuevo (no un delta — hace match con el campo `current_stock` del
  /// backend). `reason` es opcional y se manda como metadata; si el
  /// backend no la persiste, igual queda en los logs del request.
  Future<Either<Failure, InventoryItem>> adjustStock({
    required String productId,
    required int currentStock,
    int? minStockAlert,
    String? reason,
  });

  /// Histórico de movimientos de stock para un producto (más recientes
  /// primero). Backend: `GET /products/:id/inventory-history`.
  Future<Either<Failure, List<InventoryMovement>>> getInventoryHistory({
    required String productId,
    int limit = 50,
  });
}
