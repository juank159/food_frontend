import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/subscription.dart';
import '../entities/subscription_plan.dart';
import '../entities/subscription_usage.dart';

/// Subscription Repository Interface
/// Defines all subscription-related operations
abstract class SubscriptionRepository {
  /// Get all available subscription plans
  Future<Either<Failure, List<SubscriptionPlan>>> getPlans();

  /// Get current user's subscription
  Future<Either<Failure, Subscription>> getCurrentSubscription();

  /// Get subscription usage and limits
  Future<Either<Failure, SubscriptionUsage>> getUsage();

  /// Change subscription plan
  Future<Either<Failure, Subscription>> changePlan({
    required String planCode,
    String? billingCycle,
  });

  /// Cancel subscription
  Future<Either<Failure, Subscription>> cancelSubscription({
    required bool immediately,
    String? reason,
  });

  /// Check if a feature is available
  Future<Either<Failure, bool>> checkFeature(String featureName);

  /// Check limit status for a resource
  Future<Either<Failure, Map<String, dynamic>>> checkLimit({
    required String limitName,
    required int currentUsage,
  });
}
