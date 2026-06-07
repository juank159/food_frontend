import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/table.dart';
import '../repositories/table_repository.dart';

/// Get Available Tables Use Case
/// Obtiene todas las mesas disponibles con filtros opcionales
class GetAvailableTablesUseCase {
  final TableRepository repository;

  GetAvailableTablesUseCase(this.repository);

  Future<Either<Failure, List<RestaurantTable>>> call({
    int? minCapacity,
    String? zone,
  }) async {
    return await repository.getAvailableTables(
      minCapacity: minCapacity,
      zone: zone,
    );
  }
}
