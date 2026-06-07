import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/table.dart';
import '../repositories/table_repository.dart';

/// Occupy Table Use Case
/// Marca una mesa como ocupada
class OccupyTableUseCase {
  final TableRepository repository;

  OccupyTableUseCase(this.repository);

  Future<Either<Failure, RestaurantTable>> call({
    required String id,
    String? orderId,
    String? assignedTo,
  }) async {
    return await repository.occupyTable(
      id: id,
      orderId: orderId,
      assignedTo: assignedTo,
    );
  }
}
