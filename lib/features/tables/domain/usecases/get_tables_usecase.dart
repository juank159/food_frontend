import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/table_enums.dart';
import '../../../../core/error/failures.dart';
import '../entities/table.dart';
import '../repositories/table_repository.dart';

/// Get Tables Use Case
/// Obtiene la lista de mesas con filtros opcionales
class GetTablesUseCase {
  final TableRepository repository;

  GetTablesUseCase(this.repository);

  Future<Either<Failure, List<RestaurantTable>>> call({
    TableStatus? status,
    String? zone,
    String? section,
    bool? isActive,
  }) async {
    return await repository.getTables(
      status: status,
      zone: zone,
      section: section,
      isActive: isActive,
    );
  }
}
