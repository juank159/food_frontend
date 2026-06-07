import '../../domain/entities/table_status.dart';
import '../../domain/entities/table_operations.dart';
import '../datasources/table_status_datasource.dart';

abstract class TableStatusRepository {
  Future<List<TableStatusEntity>> getTableStatusByFloorPlan(String floorPlanId);
  Future<TableStatusEntity> getTableStatus(String tableElementId);
  Future<TableStatusEntity> upsertTableStatus(CreateTableStatusDto dto);
  Future<TableStatusEntity> updateTableStatus(
    String tableElementId,
    UpdateTableStatusDto dto,
  );
  Future<TableStatusEntity> occupyTable(String tableElementId, OccupyTableDto dto);
  Future<TableStatusEntity> releaseTable(String tableElementId);
  Future<TableStatusEntity> markTableAsAvailable(String tableElementId);
  Future<TableStatusEntity> reserveTable(String tableElementId, ReserveTableDto dto);
  Future<Map<String, int>> syncWithFloorPlan(String floorPlanId);
}

class TableStatusRepositoryImpl implements TableStatusRepository {
  final TableStatusDatasource datasource;

  TableStatusRepositoryImpl({required this.datasource});

  @override
  Future<List<TableStatusEntity>> getTableStatusByFloorPlan(
    String floorPlanId,
  ) async {
    try {
      return await datasource.getTableStatusByFloorPlan(floorPlanId);
    } catch (e) {
      throw Exception('Error obteniendo estados de mesas: $e');
    }
  }

  @override
  Future<TableStatusEntity> getTableStatus(String tableElementId) async {
    try {
      return await datasource.getTableStatus(tableElementId);
    } catch (e) {
      throw Exception('Error obteniendo estado de mesa: $e');
    }
  }

  @override
  Future<TableStatusEntity> upsertTableStatus(CreateTableStatusDto dto) async {
    try {
      return await datasource.upsertTableStatus(dto);
    } catch (e) {
      throw Exception('Error creando/actualizando estado de mesa: $e');
    }
  }

  @override
  Future<TableStatusEntity> updateTableStatus(
    String tableElementId,
    UpdateTableStatusDto dto,
  ) async {
    try {
      return await datasource.updateTableStatus(tableElementId, dto);
    } catch (e) {
      throw Exception('Error actualizando estado de mesa: $e');
    }
  }

  @override
  Future<TableStatusEntity> occupyTable(
    String tableElementId,
    OccupyTableDto dto,
  ) async {
    try {
      return await datasource.occupyTable(tableElementId, dto);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<TableStatusEntity> releaseTable(String tableElementId) async {
    try {
      return await datasource.releaseTable(tableElementId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<TableStatusEntity> markTableAsAvailable(String tableElementId) async {
    try {
      return await datasource.markTableAsAvailable(tableElementId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<TableStatusEntity> reserveTable(
    String tableElementId,
    ReserveTableDto dto,
  ) async {
    try {
      return await datasource.reserveTable(tableElementId, dto);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, int>> syncWithFloorPlan(String floorPlanId) async {
    try {
      return await datasource.syncWithFloorPlan(floorPlanId);
    } catch (e) {
      throw Exception('Error sincronizando mesas: $e');
    }
  }
}
