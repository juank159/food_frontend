# Guía de Implementación del Módulo de Suscripciones

## Archivos Ya Creados ✅

1. **Models (Data Layer)**
   - `lib/features/subscriptions/data/models/subscription_plan_model.dart`
   - `lib/features/subscriptions/data/models/subscription_model.dart`
   - `lib/features/subscriptions/data/models/subscription_usage_model.dart`

2. **Entities (Domain Layer)**
   - `lib/features/subscriptions/domain/entities/subscription_plan.dart`
   - `lib/features/subscriptions/domain/entities/subscription.dart`
   - `lib/features/subscriptions/domain/entities/subscription_usage.dart`

3. **Data Sources**
   - `lib/features/subscriptions/data/datasources/subscription_remote_datasource.dart`

4. **Repositories**
   - `lib/features/subscriptions/data/repositories/subscription_repository_impl.dart`

5. **Constants**
   - Agregados endpoints en `lib/core/config/constants/api_constants.dart`

## Archivos Pendientes por Crear 📝

### 1. Domain Layer

#### `lib/features/subscriptions/domain/repositories/subscription_repository.dart`
```dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/subscription.dart';
import '../entities/subscription_plan.dart';
import '../entities/subscription_usage.dart';

abstract class SubscriptionRepository {
  Future<Either<Failure, List<SubscriptionPlan>>> getPlans();
  Future<Either<Failure, Subscription>> getCurrentSubscription();
  Future<Either<Failure, SubscriptionUsage>> getUsage();
  Future<Either<Failure, Subscription>> changePlan({
    required String planCode,
    String? billingCycle,
  });
  Future<Either<Failure, Subscription>> cancelSubscription({
    required bool immediately,
    String? reason,
  });
  Future<Either<Failure, bool>> checkFeature(String featureName);
  Future<Either<Failure, Map<String, dynamic>>> checkLimit({
    required String limitName,
    required int currentUsage,
  });
}
```

#### Use Cases (Crear un archivo por cada caso de uso)

**`lib/features/subscriptions/domain/usecases/get_plans_usecase.dart`**
```dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/subscription_plan.dart';
import '../repositories/subscription_repository.dart';

class GetPlansUseCase {
  final SubscriptionRepository repository;

  GetPlansUseCase(this.repository);

  Future<Either<Failure, List<SubscriptionPlan>>> call() async {
    return await repository.getPlans();
  }
}
```

**`lib/features/subscriptions/domain/usecases/get_current_subscription_usecase.dart`**
```dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/subscription.dart';
import '../repositories/subscription_repository.dart';

class GetCurrentSubscriptionUseCase {
  final SubscriptionRepository repository;

  GetCurrentSubscriptionUseCase(this.repository);

  Future<Either<Failure, Subscription>> call() async {
    return await repository.getCurrentSubscription();
  }
}
```

**`lib/features/subscriptions/domain/usecases/get_usage_usecase.dart`**
```dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/subscription_usage.dart';
import '../repositories/subscription_repository.dart';

class GetUsageUseCase {
  final SubscriptionRepository repository;

  GetUsageUseCase(this.repository);

  Future<Either<Failure, SubscriptionUsage>> call() async {
    return await repository.getUsage();
  }
}
```

**`lib/features/subscriptions/domain/usecases/change_plan_usecase.dart`**
```dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/subscription.dart';
import '../repositories/subscription_repository.dart';

class ChangePlanParams {
  final String planCode;
  final String? billingCycle;

  ChangePlanParams({
    required this.planCode,
    this.billingCycle,
  });
}

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
```

**`lib/features/subscriptions/domain/usecases/cancel_subscription_usecase.dart`**
```dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/subscription.dart';
import '../repositories/subscription_repository.dart';

class CancelSubscriptionParams {
  final bool immediately;
  final String? reason;

  CancelSubscriptionParams({
    required this.immediately,
    this.reason,
  });
}

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
```

### 2. Presentation Layer

#### `lib/features/subscriptions/presentation/controllers/subscription_controller.dart`
```dart
import 'package:get/get.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/entities/subscription_usage.dart';
import '../../domain/usecases/get_plans_usecase.dart';
import '../../domain/usecases/get_current_subscription_usecase.dart';
import '../../domain/usecases/get_usage_usecase.dart';
import '../../domain/usecases/change_plan_usecase.dart';
import '../../domain/usecases/cancel_subscription_usecase.dart';

class SubscriptionController extends GetxController {
  final GetPlansUseCase getPlansUseCase;
  final GetCurrentSubscriptionUseCase getCurrentSubscriptionUseCase;
  final GetUsageUseCase getUsageUseCase;
  final ChangePlanUseCase changePlanUseCase;
  final CancelSubscriptionUseCase cancelSubscriptionUseCase;

  SubscriptionController({
    required this.getPlansUseCase,
    required this.getCurrentSubscriptionUseCase,
    required this.getUsageUseCase,
    required this.changePlanUseCase,
    required this.cancelSubscriptionUseCase,
  });

  // Observable states
  final RxList<SubscriptionPlan> plans = <SubscriptionPlan>[].obs;
  final Rx<Subscription?> currentSubscription = Rx<Subscription?>(null);
  final Rx<SubscriptionUsage?> usage = Rx<SubscriptionUsage?>(null);

  final RxBool isLoadingPlans = false.obs;
  final RxBool isLoadingSubscription = false.obs;
  final RxBool isLoadingUsage = false.obs;
  final RxBool isChangingPlan = false.obs;
  final RxBool isCancelling = false.obs;

  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadAllData();
  }

  Future<void> loadAllData() async {
    await Future.wait([
      loadPlans(),
      loadCurrentSubscription(),
      loadUsage(),
    ]);
  }

  Future<void> loadPlans() async {
    isLoadingPlans.value = true;
    errorMessage.value = '';

    final result = await getPlansUseCase();

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        isLoadingPlans.value = false;
      },
      (plansList) {
        plans.value = plansList;
        isLoadingPlans.value = false;
      },
    );
  }

  Future<void> loadCurrentSubscription() async {
    isLoadingSubscription.value = true;

    final result = await getCurrentSubscriptionUseCase();

    result.fold(
      (failure) {
        isLoadingSubscription.value = false;
      },
      (subscription) {
        currentSubscription.value = subscription;
        isLoadingSubscription.value = false;
      },
    );
  }

  Future<void> loadUsage() async {
    isLoadingUsage.value = true;

    final result = await getUsageUseCase();

    result.fold(
      (failure) {
        isLoadingUsage.value = false;
      },
      (usageData) {
        usage.value = usageData;
        isLoadingUsage.value = false;
      },
    );
  }

  Future<void> changePlan(String planCode, {String? billingCycle}) async {
    isChangingPlan.value = true;
    errorMessage.value = '';

    final result = await changePlanUseCase(
      ChangePlanParams(
        planCode: planCode,
        billingCycle: billingCycle,
      ),
    );

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        isChangingPlan.value = false;
        Get.snackbar(
          'Error',
          failure.message,
          snackPosition: SnackPosition.BOTTOM,
        );
      },
      (subscription) {
        currentSubscription.value = subscription;
        isChangingPlan.value = false;
        Get.snackbar(
          'Éxito',
          'Plan cambiado exitosamente',
          snackPosition: SnackPosition.BOTTOM,
        );
        loadUsage(); // Refresh usage
      },
    );
  }

  Future<void> cancelSubscription({
    required bool immediately,
    String? reason,
  }) async {
    isCancelling.value = true;
    errorMessage.value = '';

    final result = await cancelSubscriptionUseCase(
      CancelSubscriptionParams(
        immediately: immediately,
        reason: reason,
      ),
    );

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        isCancelling.value = false;
        Get.snackbar(
          'Error',
          failure.message,
          snackPosition: SnackPosition.BOTTOM,
        );
      },
      (subscription) {
        currentSubscription.value = subscription;
        isCancelling.value = false;
        Get.snackbar(
          'Éxito',
          immediately
              ? 'Suscripción cancelada'
              : 'La suscripción se cancelará al final del periodo',
          snackPosition: SnackPosition.BOTTOM,
        );
      },
    );
  }

  Future<void> refresh() async {
    await loadAllData();
  }

  // Getters
  bool get hasActiveSubscription => currentSubscription.value?.isActive ?? false;
  bool get isOnTrial => currentSubscription.value?.isTrialActive ?? false;
  String get currentPlanCode => usage.value?.planCode ?? 'free';
  String get currentPlanName => usage.value?.planName ?? 'Gratis';

  // Check if can upgrade to a specific plan
  bool canUpgradeTo(SubscriptionPlan plan) {
    if (!hasActiveSubscription) return false;
    final current = currentSubscription.value;
    if (current == null || current.plan == null) return false;
    return plan.price > current.plan!.price;
  }
}
```

#### `lib/features/subscriptions/presentation/bindings/subscription_binding.dart`
```dart
import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/cancel_subscription_usecase.dart';
import '../../domain/usecases/change_plan_usecase.dart';
import '../../domain/usecases/get_current_subscription_usecase.dart';
import '../../domain/usecases/get_plans_usecase.dart';
import '../../domain/usecases/get_usage_usecase.dart';
import '../controllers/subscription_controller.dart';

class SubscriptionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SubscriptionController>(
      () => SubscriptionController(
        getPlansUseCase: sl<GetPlansUseCase>(),
        getCurrentSubscriptionUseCase: sl<GetCurrentSubscriptionUseCase>(),
        getUsageUseCase: sl<GetUsageUseCase>(),
        changePlanUseCase: sl<ChangePlanUseCase>(),
        cancelSubscriptionUseCase: sl<CancelSubscriptionUseCase>(),
      ),
    );
  }
}
```

### 3. Dependency Injection

Agregar al archivo `lib/core/di/injection_container.dart`:

```dart
// Subscription Use Cases
sl.registerLazySingleton(() => GetPlansUseCase(sl()));
sl.registerLazySingleton(() => GetCurrentSubscriptionUseCase(sl()));
sl.registerLazySingleton(() => GetUsageUseCase(sl()));
sl.registerLazySingleton(() => ChangePlanUseCase(sl()));
sl.registerLazySingleton(() => CancelSubscriptionUseCase(sl()));

// Subscription Repository
sl.registerLazySingleton<SubscriptionRepository>(
  () => SubscriptionRepositoryImpl(
    remoteDataSource: sl(),
    networkInfo: sl(),
  ),
);

// Subscription Data Source
sl.registerLazySingleton<SubscriptionRemoteDataSource>(
  () => SubscriptionRemoteDataSourceImpl(dio: sl()),
);
```

### 4. Rutas

Agregar al archivo `lib/core/routes/app_routes.dart`:

```dart
static const String subscription = '/subscription';
static const String subscriptionPlans = '/subscription/plans';
```

Agregar al archivo `lib/core/routes/app_pages.dart`:

```dart
GetPage(
  name: AppRoutes.subscription,
  page: () => const SubscriptionPage(),
  binding: SubscriptionBinding(),
  middlewares: [AuthGuard()],
),
GetPage(
  name: AppRoutes.subscriptionPlans,
  page: () => const SubscriptionPlansPage(),
  binding: SubscriptionBinding(),
  middlewares: [AuthGuard()],
),
```

## Próximos Pasos

1. Crear los archivos de casos de uso (usecases)
2. Crear el controller con GetX
3. Crear los widgets reutilizables (cards, progress bars, etc.)
4. Crear la página de suscripción
5. Crear la página de cambio de planes
6. Integrar con el perfil del usuario
7. Configurar la inyección de dependencias
8. Agregar las rutas
9. Probar la implementación completa

## Widgets Sugeridos

1. **SubscriptionCard** - Card con información del plan actual
2. **PlanCard** - Card para mostrar cada plan disponible
3. **FeatureListItem** - Item de lista para features
4. **LimitProgressBar** - Barra de progreso para límites
5. **TrialBanner** - Banner informativo del trial
6. **UpgradeButton** - Botón para hacer upgrade

## Endpoints Disponibles

- GET `/subscriptions/plans` - Obtener todos los planes
- GET `/subscriptions/current` - Obtener suscripción actual
- GET `/subscriptions/usage` - Obtener uso y límites
- POST `/subscriptions/change-plan` - Cambiar de plan
- POST `/subscriptions/cancel` - Cancelar suscripción
- POST `/subscriptions/check-feature` - Verificar feature
- POST `/subscriptions/check-limit` - Verificar límite
