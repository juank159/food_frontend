import 'package:dio/dio.dart';
import '../../domain/entities/table_status.dart';
import '../../domain/entities/table_operations.dart';

abstract class TableStatusDatasource {
  /// Obtener todos los estados de mesas de un floor plan
  Future<List<TableStatusEntity>> getTableStatusByFloorPlan(String floorPlanId);

  /// Obtener el estado de una mesa específica
  Future<TableStatusEntity> getTableStatus(String tableElementId);

  /// Crear o actualizar estado de una mesa
  Future<TableStatusEntity> upsertTableStatus(CreateTableStatusDto dto);

  /// Actualizar estado de una mesa
  Future<TableStatusEntity> updateTableStatus(
    String tableElementId,
    UpdateTableStatusDto dto,
  );

  /// Ocupar una mesa
  Future<TableStatusEntity> occupyTable(
    String tableElementId,
    OccupyTableDto dto,
  );

  /// Liberar una mesa (marcar como limpieza)
  Future<TableStatusEntity> releaseTable(String tableElementId);

  /// Marcar mesa como disponible (después de limpieza)
  Future<TableStatusEntity> markTableAsAvailable(String tableElementId);

  /// Reservar una mesa
  Future<TableStatusEntity> reserveTable(
    String tableElementId,
    ReserveTableDto dto,
  );

  /// Sincronizar estados de mesas con el floor plan
  Future<Map<String, int>> syncWithFloorPlan(String floorPlanId);
}

class TableStatusDatasourceImpl implements TableStatusDatasource {
  final Dio dio;

  TableStatusDatasourceImpl({required this.dio});

  @override
  Future<List<TableStatusEntity>> getTableStatusByFloorPlan(
    String floorPlanId,
  ) async {
    try {
      final response = await dio.get('/table-status/floor-plan/$floorPlanId');

      final data = response.data as List;
      return data
          .map((json) => TableStatusEntity.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('Error fetching table statuses: ${e.message}');
    }
  }

  @override
  Future<TableStatusEntity> getTableStatus(String tableElementId) async {
    try {
      final response = await dio.get('/table-status/$tableElementId');
      return TableStatusEntity.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Error fetching table status: ${e.message}');
    }
  }

  @override
  Future<TableStatusEntity> upsertTableStatus(CreateTableStatusDto dto) async {
    try {
      final response = await dio.post(
        '/table-status',
        data: dto.toJson(),
      );
      return TableStatusEntity.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Error creating/updating table status: ${e.message}');
    }
  }

  @override
  Future<TableStatusEntity> updateTableStatus(
    String tableElementId,
    UpdateTableStatusDto dto,
  ) async {
    try {
      final response = await dio.patch(
        '/table-status/$tableElementId',
        data: dto.toJson(),
      );
      return TableStatusEntity.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Error updating table status: ${e.message}');
    }
  }

  @override
  Future<TableStatusEntity> occupyTable(
    String tableElementId,
    OccupyTableDto dto,
  ) async {
    try {
      final response = await dio.post(
        '/table-status/$tableElementId/occupy',
        data: dto.toJson(),
      );
      return TableStatusEntity.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw Exception('La mesa no está disponible para ocupar');
      }
      throw Exception('Error ocupando mesa: ${e.message}');
    }
  }

  @override
  Future<TableStatusEntity> releaseTable(String tableElementId) async {
    try {
      final response = await dio.post('/table-status/$tableElementId/release');
      return TableStatusEntity.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Error liberando mesa: ${e.message}');
    }
  }

  @override
  Future<TableStatusEntity> markTableAsAvailable(String tableElementId) async {
    try {
      final response =
          await dio.post('/table-status/$tableElementId/available');
      return TableStatusEntity.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Error marcando mesa como disponible: ${e.message}');
    }
  }

  @override
  Future<TableStatusEntity> reserveTable(
    String tableElementId,
    ReserveTableDto dto,
  ) async {
    try {
      final response = await dio.post(
        '/table-status/$tableElementId/reserve',
        data: dto.toJson(),
      );
      return TableStatusEntity.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw Exception('La mesa no está disponible para reservar');
      }
      throw Exception('Error reservando mesa: ${e.message}');
    }
  }

  @override
  Future<Map<String, int>> syncWithFloorPlan(String floorPlanId) async {
    try {
      final response = await dio.post('/table-status/sync/$floorPlanId');
      final data = response.data as Map<String, dynamic>;
      return {
        'created': data['created'] as int,
        'deleted': data['deleted'] as int,
      };
    } on DioException catch (e) {
      throw Exception('Error sincronizando mesas: ${e.message}');
    }
  }
}
