import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/tenant_payment_account.dart';
import '../../domain/repositories/tenant_payment_account_repository.dart';
import '../datasources/tenant_payment_account_remote_datasource.dart';

class TenantPaymentAccountRepositoryImpl
    implements TenantPaymentAccountRepository {
  final TenantPaymentAccountRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  TenantPaymentAccountRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  Future<Either<Failure, T>> _run<T>(Future<T> Function() action) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      final result = await action();
      return Right(result);
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<TenantPaymentAccount>>> getAll({
    PaymentMethod? category,
    bool? onlyActive,
  }) {
    return _run(() async {
      final models = await remoteDataSource.getAll(
        category: category,
        onlyActive: onlyActive,
      );
      return models.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, TenantPaymentAccount>> getById(String id) {
    return _run(() async {
      final model = await remoteDataSource.getById(id);
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, TenantPaymentAccount>> create({
    required String name,
    required PaymentMethod category,
    String? accountNumber,
    String? accountHolder,
    String? icon,
    String? notes,
    bool? isActive,
    int? sortOrder,
  }) {
    return _run(() async {
      final model = await remoteDataSource.create({
        'name': name,
        'category': category.value,
        if (accountNumber != null) 'account_number': accountNumber,
        if (accountHolder != null) 'account_holder': accountHolder,
        if (icon != null) 'icon': icon,
        if (notes != null) 'notes': notes,
        if (isActive != null) 'is_active': isActive,
        if (sortOrder != null) 'sort_order': sortOrder,
      });
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, TenantPaymentAccount>> update({
    required String id,
    String? name,
    PaymentMethod? category,
    String? accountNumber,
    String? accountHolder,
    String? icon,
    String? notes,
    bool? isActive,
    int? sortOrder,
  }) {
    return _run(() async {
      final model = await remoteDataSource.update(id, {
        if (name != null) 'name': name,
        if (category != null) 'category': category.value,
        if (accountNumber != null) 'account_number': accountNumber,
        if (accountHolder != null) 'account_holder': accountHolder,
        if (icon != null) 'icon': icon,
        if (notes != null) 'notes': notes,
        if (isActive != null) 'is_active': isActive,
        if (sortOrder != null) 'sort_order': sortOrder,
      });
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, TenantPaymentAccount>> toggleActive(String id) {
    return _run(() async {
      final model = await remoteDataSource.toggleActive(id);
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, void>> delete(String id) {
    return _run(() => remoteDataSource.delete(id));
  }
}
