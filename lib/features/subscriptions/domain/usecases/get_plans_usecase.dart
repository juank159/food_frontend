import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/subscription_plan.dart';
import '../repositories/subscription_repository.dart';

/// Use Case: Get all subscription plans
class GetPlansUseCase {
  final SubscriptionRepository repository;

  GetPlansUseCase(this.repository);

  Future<Either<Failure, List<SubscriptionPlan>>> call() async {
    return await repository.getPlans();
  }
}
