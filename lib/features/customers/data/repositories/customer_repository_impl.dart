import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_address.dart';
import '../../domain/entities/customer_statistics.dart';
import '../../domain/repositories/customer_repository.dart';
import '../datasources/customer_local_datasource.dart';
import '../datasources/customer_remote_datasource.dart';

/// Customer Repository Implementation
///
/// Estrategia cache-first:
///   - getCustomers(): sirve desde caché local si está fresca (<4 h); si no,
///     va al backend y actualiza la caché.
///   - getCustomerById() / getCustomerByPhone(): si hay caché fresca y no hay
///     conexión, busca en la caché local en lugar de fallar con NetworkFailure.
///   - Operaciones de escritura: siempre requieren conexión.
class CustomerRepositoryImpl implements CustomerRepository {
  final CustomerRemoteDataSource remoteDataSource;
  final CustomerLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  CustomerRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// Ejecuta [action] solo si hay conexión y convierte excepciones en Failure.
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    return _run(action);
  }

  /// Ejecuta [action] y convierte excepciones en Failure (sin check de red).
  Future<Either<Failure, T>> _run<T>(Future<T> Function() action) async {
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

  // -------------------------------------------------------------------------
  // Read operations — cache-first
  // -------------------------------------------------------------------------

  @override
  Future<Either<Failure, List<Customer>>> getCustomers({
    bool? isActive,
    String? search,
  }) async {
    // Cache-first: si la caché está fresca, devuelve sin tocar la red.
    // Nota: la caché no distingue parámetros de filtro; filtros activos
    // como isActive/search siempre van al backend para exactitud.
    final bool hasFilters = isActive != null || (search != null && search.isNotEmpty);
    if (!hasFilters && localDataSource.hasFreshCache) {
      final cached = await localDataSource.getCachedCustomers();
      if (cached != null) {
        return Right(cached.map((m) => m.toEntity()).toList());
      }
    }

    // Sin caché fresca o con filtros: va al backend.
    return _guard(() async {
      final models = await remoteDataSource.getCustomers(
        isActive: isActive,
        search: search,
      );
      // Actualiza caché solo cuando no hay filtros activos para no
      // almacenar listas parciales.
      if (!hasFilters) {
        final rawList = models
            .map((m) => _modelToRawMap(m))
            .toList();
        await localDataSource.cacheCustomers(rawList);
      }
      return models.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, Customer>> getCustomerById(String id) async {
    final isConnected = await networkInfo.isConnected;

    if (!isConnected) {
      // Intenta resolver desde caché local.
      final cached = await localDataSource.getCachedCustomers();
      if (cached != null) {
        try {
          final model = cached.firstWhere((m) => m.id == id);
          return Right(model.toEntity());
        } catch (_) {
          // firstWhere lanza StateError si no encuentra.
          return const Left(NetworkFailure());
        }
      }
      return const Left(NetworkFailure());
    }

    return _run(() async {
      final result = await remoteDataSource.getCustomerById(id);
      return result.toEntity();
    });
  }

  @override
  Future<Either<Failure, Customer?>> getCustomerByPhone(String phone) async {
    final isConnected = await networkInfo.isConnected;

    if (!isConnected) {
      // Busca en caché local vía el helper dedicado.
      final cached = await localDataSource.findByPhone(phone);
      return Right(cached?.toEntity());
    }

    return _run(() async {
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

  // -------------------------------------------------------------------------
  // Write operations — siempre requieren conexión
  // -------------------------------------------------------------------------

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

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  /// Convierte un CustomerModel a Map raw compatible con cacheCustomers.
  /// CustomerModel no tiene toJson(), así que lo construimos manualmente
  /// usando los mismos field names que espera fromJson().
  Map<String, dynamic> _modelToRawMap(dynamic m) {
    // m es CustomerModel; usamos dynamic para evitar import circular
    // (el tipo ya está importado a través de remoteDataSource).
    return {
      'id': m.id,
      'full_name': m.fullName,
      'phone': m.phone,
      'email': m.email,
      'default_address_id': m.defaultAddressId,
      'total_orders': m.totalOrders,
      'total_spent': m.totalSpent,
      'last_order_date': m.lastOrderDate,
      'notes': m.notes,
      'is_active': m.isActive,
      'addresses': const <Map<String, dynamic>>[],
      'created_at': m.createdAt,
      'updated_at': m.updatedAt,
    };
  }
}
