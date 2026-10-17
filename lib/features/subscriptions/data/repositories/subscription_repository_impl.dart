import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/services/local_cache_service.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/entities/subscription_usage.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../datasources/subscription_remote_datasource.dart';
import '../models/subscription_model.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final SubscriptionRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;
  final LocalCacheService localCache;

  SubscriptionRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
    required this.localCache,
  });

  @override
  Future<Either<Failure, List<SubscriptionPlan>>> getPlans() async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getPlans();
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Error inesperado: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  /// OJO: esta caché es SOLO para mostrar algo razonable en pantalla
  /// (ej. "tu plan: Pro, vence el 12/11") mientras no hay conexión —
  /// JAMÁS se usa para decidir si una acción se permite o no. El gate
  /// real de plan vencido (`@RequiresActivePlan()`) vive en el
  /// backend a propósito, para que no se pueda saltar mostrando un
  /// estado de plan desactualizado. Si el trial venció mientras el
  /// dispositivo estaba offline, las operaciones encoladas (crear
  /// orden, pago) simplemente las va a rechazar el servidor al
  /// sincronizar — acá no se intenta adivinar ni bloquear nada.
  @override
  Future<Either<Failure, Subscription>> getCurrentSubscription() async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getCurrentSubscription();
        await localCache.saveObject(
          CacheKeys.currentSubscription,
          result.toJson(),
        );
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Error inesperado: ${e.toString()}'));
      }
    }

    final cached = localCache.getObject(CacheKeys.currentSubscription);
    if (cached != null) {
      return Right(SubscriptionModel.fromJson(cached).toEntity());
    }
    return const Left(NetworkFailure());
  }

  @override
  Future<Either<Failure, SubscriptionUsage>> getUsage() async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getUsage();
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Error inesperado: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, Subscription>> changePlan({
    required String planCode,
    String? billingCycle,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.changePlan(
          planCode: planCode,
          billingCycle: billingCycle,
        );
        return Right(result.toEntity());
      } on UnauthorizedException catch (e) {
        return Left(UnauthorizedFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Error inesperado: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, Subscription>> cancelSubscription({
    required bool immediately,
    String? reason,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.cancelSubscription(
          immediately: immediately,
          reason: reason,
        );
        return Right(result.toEntity());
      } on UnauthorizedException catch (e) {
        return Left(UnauthorizedFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Error inesperado: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, bool>> checkFeature(String featureName) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.checkFeature(featureName);
        return Right(result);
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Error inesperado: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> checkLimit({
    required String limitName,
    required int currentUsage,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.checkLimit(
          limitName: limitName,
          currentUsage: currentUsage,
        );
        return Right(result);
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Error inesperado: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }
}
