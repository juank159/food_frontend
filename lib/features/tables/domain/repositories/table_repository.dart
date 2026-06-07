import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/table_enums.dart';
import '../../../../core/error/failures.dart';
import '../entities/table.dart';

/// Table Repository Interface
/// Define los contratos para operaciones con mesas
abstract class TableRepository {
  /// Obtener todas las mesas con filtros opcionales
  Future<Either<Failure, List<RestaurantTable>>> getTables({
    TableStatus? status,
    String? zone,
    String? section,
    bool? isActive,
  });

  /// Obtener una mesa por ID
  Future<Either<Failure, RestaurantTable>> getTableById(String id);

  /// Obtener una mesa por número
  Future<Either<Failure, RestaurantTable>> getTableByNumber(String tableNumber);

  /// Obtener mesas disponibles
  Future<Either<Failure, List<RestaurantTable>>> getAvailableTables({
    int? minCapacity,
    String? zone,
  });

  /// Obtener mesas ocupadas
  Future<Either<Failure, List<RestaurantTable>>> getOccupiedTables();

  /// Obtener mesas por zona
  Future<Either<Failure, List<RestaurantTable>>> getTablesByZone(String zone);

  /// Obtener mesas por sección
  Future<Either<Failure, List<RestaurantTable>>> getTablesBySection(
      String section);

  /// Crear una nueva mesa
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
  });

  /// Actualizar una mesa
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
  });

  /// Actualizar el estado de una mesa
  Future<Either<Failure, RestaurantTable>> updateTableStatus({
    required String id,
    required TableStatus status,
  });

  /// Ocupar una mesa
  Future<Either<Failure, RestaurantTable>> occupyTable({
    required String id,
    String? orderId,
    String? assignedTo,
  });

  /// Liberar una mesa
  Future<Either<Failure, RestaurantTable>> releaseTable(String id);

  /// Reservar una mesa
  Future<Either<Failure, RestaurantTable>> reserveTable({
    required String id,
    String? customerName,
    DateTime? reservationTime,
  });

  /// Marcar mesa para limpieza
  Future<Either<Failure, RestaurantTable>> markForCleaning(String id);

  /// Completar limpieza de mesa
  Future<Either<Failure, RestaurantTable>> completeCleaning(String id);

  /// Eliminar una mesa
  Future<Either<Failure, void>> deleteTable(String id);

  /// Obtener layout de mesas
  Future<Either<Failure, List<RestaurantTable>>> getTableLayout();

  /// Actualizar posición de una mesa en el mapa visual
  Future<Either<Failure, RestaurantTable>> updateTablePosition({
    required String id,
    required double positionX,
    required double positionY,
    double? width,
    double? height,
    String? shape,
  });
}
