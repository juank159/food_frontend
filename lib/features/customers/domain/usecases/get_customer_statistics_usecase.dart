import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/customer_statistics.dart';
import '../repositories/customer_repository.dart';

/// Get Customer Statistics Use Case
class GetCustomerStatisticsUseCase {
  final CustomerRepository repository;

  GetCustomerStatisticsUseCase(this.repository);

  Future<Either<Failure, CustomerStatistics>> call() async {
    return repository.getStatistics();
  }
}
