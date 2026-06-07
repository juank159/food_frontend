import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/table_enums.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/table.dart';
import '../../domain/repositories/table_repository.dart';
import '../datasources/table_remote_datasource.dart';

/// Table Repository Implementation
/// Implementación concreta del repositorio de mesas
class TableRepositoryImpl implements TableRepository {
  final TableRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  TableRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<RestaurantTable>>> getTables({
    TableStatus? status,
    String? zone,
    String? section,
    bool? isActive,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getTables(
          status: status,
          zone: zone,
          section: section,
          isActive: isActive,
        );
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Mesas no encontradas'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, RestaurantTable>> getTableById(String id) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getTableById(id);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Mesa no encontrada'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, RestaurantTable>> getTableByNumber(
      String tableNumber) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getTableByNumber(tableNumber);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Mesa no encontrada'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, List<RestaurantTable>>> getAvailableTables({
    int? minCapacity,
    String? zone,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getAvailableTables(
          minCapacity: minCapacity,
          zone: zone,
        );
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Mesas disponibles no encontradas'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, List<RestaurantTable>>> getOccupiedTables() async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getOccupiedTables();
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Mesas ocupadas no encontradas'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, List<RestaurantTable>>> getTablesByZone(
      String zone) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getTablesByZone(zone);
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Mesas no encontradas'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, List<RestaurantTable>>> getTablesBySection(
      String section) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getTablesBySection(section);
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Mesas no encontradas'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, RestaurantTable>> createTable({
    required String tableNumber,
    String? name,
    required int capacity,
    int? minCapacity,
    TableType? tableType,
    TableShape? shape,
    String? zone,
    String? section,
    int? positionX,
    int? positionY,
    double? width,
    double? height,
    Map<String, dynamic>? metadata,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final tableData = <String, dynamic>{
          'table_number': tableNumber,
          'capacity': capacity,
        };

        if (name != null) tableData['name'] = name;
        if (minCapacity != null) tableData['min_capacity'] = minCapacity;
        if (tableType != null) tableData['table_type'] = tableType.value;
        if (shape != null) tableData['shape'] = shape.value;
        if (zone != null) tableData['zone'] = zone;
        if (section != null) tableData['section'] = section;
        if (positionX != null) tableData['position_x'] = positionX;
        if (positionY != null) tableData['position_y'] = positionY;
        if (width != null) tableData['width'] = width;
        if (height != null) tableData['height'] = height;
        if (metadata != null) tableData['metadata'] = metadata;

        final result = await remoteDataSource.createTable(tableData);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, RestaurantTable>> updateTable({
    required String id,
    String? tableNumber,
    String? name,
    int? capacity,
    int? minCapacity,
    TableStatus? status,
    TableType? tableType,
    TableShape? shape,
    String? zone,
    String? section,
    bool? isActive,
    int? positionX,
    int? positionY,
    double? width,
    double? height,
    Map<String, dynamic>? metadata,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final tableData = <String, dynamic>{};

        if (tableNumber != null) tableData['table_number'] = tableNumber;
        if (name != null) tableData['name'] = name;
        if (capacity != null) tableData['capacity'] = capacity;
        if (minCapacity != null) tableData['min_capacity'] = minCapacity;
        if (status != null) tableData['status'] = status.value;
        if (tableType != null) tableData['table_type'] = tableType.value;
        if (shape != null) tableData['shape'] = shape.value;
        if (zone != null) tableData['zone'] = zone;
        if (section != null) tableData['section'] = section;
        if (isActive != null) tableData['is_active'] = isActive;
        if (positionX != null) tableData['position_x'] = positionX;
        if (positionY != null) tableData['position_y'] = positionY;
        if (width != null) tableData['width'] = width;
        if (height != null) tableData['height'] = height;
        if (metadata != null) tableData['metadata'] = metadata;

        final result = await remoteDataSource.updateTable(id, tableData);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Mesa no encontrada'));
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, RestaurantTable>> updateTableStatus({
    required String id,
    required TableStatus status,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.updateTableStatus(id, status);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Mesa no encontrada'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, RestaurantTable>> occupyTable({
    required String id,
    String? orderId,
    String? assignedTo,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result =
            await remoteDataSource.occupyTable(id, orderId, assignedTo);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Mesa no encontrada'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, RestaurantTable>> releaseTable(String id) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.releaseTable(id);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Mesa no encontrada'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, RestaurantTable>> reserveTable({
    required String id,
    String? customerName,
    DateTime? reservationTime,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final reservationData = <String, dynamic>{};
        if (customerName != null) {
          reservationData['customer_name'] = customerName;
        }
        if (reservationTime != null) {
          reservationData['reservation_time'] = reservationTime.toIso8601String();
        }

        final result = await remoteDataSource.reserveTable(id, reservationData);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Mesa no encontrada'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, RestaurantTable>> markForCleaning(String id) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.markForCleaning(id);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Mesa no encontrada'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, RestaurantTable>> completeCleaning(String id) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.completeCleaning(id);
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Mesa no encontrada'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> deleteTable(String id) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.deleteTable(id);
        return const Right(null);
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Mesa no encontrada'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, List<RestaurantTable>>> getTableLayout() async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.getTableLayout();
        return Right(result.map((model) => model.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Layout no encontrado'));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, RestaurantTable>> updateTablePosition({
    required String id,
    required double positionX,
    required double positionY,
    double? width,
    double? height,
    String? shape,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await remoteDataSource.updateTablePosition(
          id,
          positionX,
          positionY,
          width,
          height,
          shape,
        );
        return Right(result.toEntity());
      } on UnauthorizedException {
        return const Left(UnauthorizedFailure());
      } on NotFoundException {
        return const Left(NotFoundFailure('Mesa no encontrada'));
      } on ValidationException catch (e) {
        return Left(ValidationFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }
}
