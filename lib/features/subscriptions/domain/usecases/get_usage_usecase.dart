import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/subscription_usage.dart';
import '../repositories/subscription_repository.dart';

/// Use Case: Get subscription usage and limits
class GetUsageUseCase {
  final SubscriptionRepository repository;

  GetUsageUseCase(this.repository);

  Future<Either<Failure, SubscriptionUsage>> call() async {
    return await repository.getUsage();
  }
}
