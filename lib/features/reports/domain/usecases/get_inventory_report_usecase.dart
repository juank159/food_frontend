import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/inventory_report.dart';
import '../repositories/reports_repository.dart';

/// Get Inventory Report Use Case
///
/// Wrapper alrededor de `ReportsRepository.getInventoryReport`. No recibe
/// parámetros: el reporte es un snapshot del stock vigente y se calcula
/// 100% en cliente a partir de la lista de productos.
class GetInventoryReportUseCase {
  final ReportsRepository repository;

  GetInventoryReportUseCase(this.repository);

  Future<Either<Failure, InventoryReport>> call() {
    return repository.getInventoryReport();
  }
}
