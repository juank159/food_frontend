import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/subscription.dart';
import '../repositories/subscription_repository.dart';

/// Parameters for cancelling subscription
class CancelSubscriptionParams {
  final bool immediately;
  final String? reason;

  CancelSubscriptionParams({
    required this.immediately,
    this.reason,
  });
}

/// Use Case: Cancel subscription
class CancelSubscriptionUseCase {
  final SubscriptionRepository repository;

  CancelSubscriptionUseCase(this.repository);

  Future<Either<Failure, Subscription>> call(
      CancelSubscriptionParams params) async {
    return await repository.cancelSubscription(
      immediately: params.immediately,
      reason: params.reason,
    );
  }
}
