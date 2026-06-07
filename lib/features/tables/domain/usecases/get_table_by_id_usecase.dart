import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/table.dart';
import '../repositories/table_repository.dart';

/// Get Table By ID Use Case
/// Obtiene los detalles de una mesa específica
class GetTableByIdUseCase {
  final TableRepository repository;

  GetTableByIdUseCase(this.repository);

  Future<Either<Failure, RestaurantTable>> call(String id) async {
    return await repository.getTableById(id);
  }
}
