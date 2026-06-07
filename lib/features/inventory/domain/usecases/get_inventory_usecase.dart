import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/inventory_item.dart';
import '../repositories/inventory_repository.dart';

/// Get Inventory Use Case
///
/// Obtiene la lista completa de items de inventario. La página filtra
/// localmente por estado (todos / con stock / bajo / agotado) sin pegarle
/// otra vez al backend.
class GetInventoryUseCase {
  final InventoryRepository repository;

  GetInventoryUseCase(this.repository);

  Future<Either<Failure, List<InventoryItem>>> call({
    bool onlyTracked = false,
  }) {
    return repository.getInventory(onlyTracked: onlyTracked);
  }
}
