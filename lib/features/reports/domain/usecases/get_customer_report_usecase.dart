import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/customer_report.dart';
import '../repositories/reports_repository.dart';

/// Get Customer Report Use Case
class GetCustomerReportUseCase {
  final ReportsRepository repository;

  GetCustomerReportUseCase(this.repository);

  Future<Either<Failure, CustomerReport>> call() {
    return repository.getCustomerReport();
  }
}
