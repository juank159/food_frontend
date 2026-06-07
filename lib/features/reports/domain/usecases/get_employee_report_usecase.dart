import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/employee_report.dart';
import '../repositories/reports_repository.dart';

/// Get Employee Report Use Case
class GetEmployeeReportUseCase {
  final ReportsRepository repository;

  GetEmployeeReportUseCase(this.repository);

  Future<Either<Failure, EmployeeReport>> call() {
    return repository.getEmployeeReport();
  }
}
