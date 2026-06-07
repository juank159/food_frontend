import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/table_enums.dart';
import '../../../../core/error/failures.dart';
import '../entities/table.dart';
import '../repositories/table_repository.dart';

/// Update Table Status Use Case
/// Actualiza el estado de una mesa
class UpdateTableStatusUseCase {
  final TableRepository repository;

  UpdateTableStatusUseCase(this.repository);

  Future<Either<Failure, RestaurantTable>> call({
    required String id,
    required TableStatus status,
  }) async {
    return await repository.updateTableStatus(id: id, status: status);
  }
}
