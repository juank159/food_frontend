import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/product_sales_report.dart';
import '../repositories/reports_repository.dart';

class GetProductSalesUseCase {
  final ReportsRepository repository;
  GetProductSalesUseCase(this.repository);

  Future<Either<Failure, ProductSalesReport>> call({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) {
    return repository.getProductSalesReport(
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
  }
}
