import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/datasources/plan_billing_api.dart';
import '../../domain/usecases/cancel_subscription_usecase.dart';
import '../../domain/usecases/get_current_subscription_usecase.dart';
import '../../domain/usecases/get_plans_usecase.dart';
import '../../domain/usecases/get_usage_usecase.dart';
import '../controllers/subscription_controller.dart';

/// Subscription Binding
/// Sets up dependency injection for subscription features
class SubscriptionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SubscriptionController>(
      () => SubscriptionController(
        getPlansUseCase: sl<GetPlansUseCase>(),
        getCurrentSubscriptionUseCase: sl<GetCurrentSubscriptionUseCase>(),
        getUsageUseCase: sl<GetUsageUseCase>(),
        cancelSubscriptionUseCase: sl<CancelSubscriptionUseCase>(),
        billingApi: PlanBillingApi(sl<Dio>()),
      ),
    );
  }
}
