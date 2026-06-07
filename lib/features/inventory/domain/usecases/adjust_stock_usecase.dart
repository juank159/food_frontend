import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/inventory_item.dart';
import '../repositories/inventory_repository.dart';

/// Adjust Stock Use Case
///
/// Aplica el nuevo stock absoluto a un producto. El motivo se envía como
/// metadata del request por si el backend quiere persistir un audit log
/// más adelante; hoy es informativo nada más.
class AdjustStockUseCase {
  final InventoryRepository repository;

  AdjustStockUseCase(this.repository);

  Future<Either<Failure, InventoryItem>> call({
    required String productId,
    required int currentStock,
    int? minStockAlert,
    String? reason,
  }) {
    return repository.adjustStock(
      productId: productId,
      currentStock: currentStock,
      minStockAlert: minStockAlert,
      reason: reason,
    );
  }
}
