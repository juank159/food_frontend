import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/sales_report.dart';
import '../repositories/reports_repository.dart';

/// Get Sales Report Use Case
///
/// Wrapper alrededor de `ReportsRepository.getSalesReport` para mantener
/// la simetría con el resto de los módulos (controllers consumen
/// usecases, no repositorios directamente).
class GetSalesReportUseCase {
  final ReportsRepository repository;

  GetSalesReportUseCase(this.repository);

  Future<Either<Failure, SalesReport>> call({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    return repository.getSalesReport(dateFrom: dateFrom, dateTo: dateTo);
  }
}
