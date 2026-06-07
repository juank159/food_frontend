import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/subscription.dart';
import '../repositories/subscription_repository.dart';

/// Parameters for changing subscription plan
class ChangePlanParams {
  final String planCode;
  final String? billingCycle;

  ChangePlanParams({
    required this.planCode,
    this.billingCycle,
  });
}

/// Use Case: Change subscription plan
class ChangePlanUseCase {
  final SubscriptionRepository repository;

  ChangePlanUseCase(this.repository);

  Future<Either<Failure, Subscription>> call(ChangePlanParams params) async {
    return await repository.changePlan(
      planCode: params.planCode,
      billingCycle: params.billingCycle,
    );
  }
}
