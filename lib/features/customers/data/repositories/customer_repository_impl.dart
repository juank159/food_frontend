import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_address.dart';
import '../../domain/entities/customer_statistics.dart';
import '../../domain/repositories/customer_repository.dart';
import '../datasources/customer_remote_datasource.dart';

/// Customer Repository Implementation
///
/// Mapea excepciones del datasource a `Failure`s del dominio. Sigue el
/// mismo patrón que `CategoryRepositoryImpl` y `OrderRepositoryImpl`.
class CustomerRepositoryImpl implements CustomerRepository {
  final CustomerRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  CustomerRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
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
    } on ConflictException catch (e) {
      return Left(ConflictFailure(e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Customer>>> getCustomers({
    bool? isActive,
    String? search,
  }) {
    return _guard(() async {
      final result = await remoteDataSource.getCustomers(
        isActive: isActive,
        search: search,
      );
      return result.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, Customer>> getCustomerById(String id) {
    return _guard(() async {
      final result = await remoteDataSource.getCustomerById(id);
      return result.toEntity();
    });
  }

  @override
  Future<Either<Failure, Customer?>> getCustomerByPhone(String phone) {
    return _guard(() async {
      final result = await remoteDataSource.getCustomerByPhone(phone);
      return result?.toEntity();
    });
  }

  @override
  Future<Either<Failure, CustomerStatistics>> getStatistics() {
    return _guard(() async {
      final result = await remoteDataSource.getStatistics();
      return result.toEntity();
    });
  }

  @override
  Future<Either<Failure, List<CustomerAddress>>> getAddresses(
    String customerId,
  ) {
    return _guard(() async {
      final result = await remoteDataSource.getAddresses(customerId);
      return result.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, Customer>> createCustomer({
    required String fullName,
    required String phone,
    String? email,
    String? notes,
    bool isActive = true,
  }) {
    return _guard(() async {
      final result = await remoteDataSource.createCustomer(
        fullName: fullName,
        phone: phone,
        email: email,
        notes: notes,
        isActive: isActive,
      );
      return result.toEntity();
    });
  }

  @override
  Future<Either<Failure, Customer>> updateCustomer({
    required String id,
    String? fullName,
    String? phone,
    String? email,
    String? notes,
    bool? isActive,
  }) {
    return _guard(() async {
      final result = await remoteDataSource.updateCustomer(
        id: id,
        fullName: fullName,
        phone: phone,
        email: email,
        notes: notes,
        isActive: isActive,
      );
      return result.toEntity();
    });
  }

  @override
  Future<Either<Failure, void>> deleteCustomer(String id) {
    return _guard(() => remoteDataSource.deleteCustomer(id));
  }

  @override
  Future<Either<Failure, CustomerAddress>> createAddress({
    required String customerId,
    required String label,
    required String addressLine1,
    String? addressLine2,
    required String city,
    String? state,
    String? postalCode,
    double? latitude,
    double? longitude,
    String? deliveryInstructions,
    bool isDefault = false,
  }) {
    return _guard(() async {
      final result = await remoteDataSource.createAddress(
        customerId: customerId,
        label: label,
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        city: city,
        state: state,
        postalCode: postalCode,
        latitude: latitude,
        longitude: longitude,
        deliveryInstructions: deliveryInstructions,
        isDefault: isDefault,
      );
      return result.toEntity();
    });
  }

  @override
  Future<Either<Failure, CustomerAddress>> updateAddress({
    required String addressId,
    String? label,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? postalCode,
    double? latitude,
    double? longitude,
    String? deliveryInstructions,
    bool? isDefault,
  }) {
    return _guard(() async {
      final result = await remoteDataSource.updateAddress(
        addressId: addressId,
        label: label,
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        city: city,
        state: state,
        postalCode: postalCode,
        latitude: latitude,
        longitude: longitude,
        deliveryInstructions: deliveryInstructions,
        isDefault: isDefault,
      );
      return result.toEntity();
    });
  }

  @override
  Future<Either<Failure, void>> deleteAddress(String addressId) {
    return _guard(() => remoteDataSource.deleteAddress(addressId));
  }
}
