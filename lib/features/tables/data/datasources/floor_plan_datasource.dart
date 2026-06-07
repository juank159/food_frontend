// lib/features/tables/data/datasources/floor_plan_datasource.dart

import 'package:dio/dio.dart';
import '../../domain/entities/floor_plan.dart';

abstract class FloorPlanDataSource {
  Future<List<FloorPlan>> getFloorPlans();
  Future<FloorPlan> getFloorPlanById(String id);
  Future<FloorPlan> createFloorPlan(FloorPlan floorPlan);
  Future<FloorPlan> updateFloorPlan(String id, FloorPlan floorPlan);
  Future<void> deleteFloorPlan(String id);
  Future<FloorPlan> duplicateFloorPlan(String id, String newName);
}

class FloorPlanDataSourceImpl implements FloorPlanDataSource {
  final Dio dio;

  FloorPlanDataSourceImpl({required this.dio});

  @override
  Future<List<FloorPlan>> getFloorPlans() async {
    try {
      final response = await dio.get('/floor-plans');

      if (response.data is List) {
        return (response.data as List)
            .map((json) => FloorPlan.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw Exception('Invalid response format');
    } on DioException catch (e) {
      throw Exception('Error fetching floor plans: ${e.message}');
    }
  }

  @override
  Future<FloorPlan> getFloorPlanById(String id) async {
    try {
      final response = await dio.get('/floor-plans/$id');
      return FloorPlan.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Error fetching floor plan: ${e.message}');
    }
  }

  @override
  Future<FloorPlan> createFloorPlan(FloorPlan floorPlan) async {
    try {
      // Solo enviar los campos necesarios para crear (sin id ni campos read-only)
      final createData = {
        'name': floorPlan.name,
        'floor_level': floorPlan.floorLevel,
        'layers': floorPlan.layers.map((l) => l.toJson()).toList(),
        'canvas_width': floorPlan.canvasWidth,
        'canvas_height': floorPlan.canvasHeight,
        'grid_size': floorPlan.gridSize,
        'show_grid': floorPlan.showGrid,
        if (floorPlan.backgroundImageUrl != null)
          'background_image_url': floorPlan.backgroundImageUrl,
        if (floorPlan.metadata != null) 'metadata': floorPlan.metadata,
      };

      final response = await dio.post(
        '/floor-plans',
        data: createData,
      );
      return FloorPlan.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Error creating floor plan: ${e.message}');
    }
  }

  @override
  Future<FloorPlan> updateFloorPlan(String id, FloorPlan floorPlan) async {
    try {
      // Solo enviar los campos que el backend acepta en PATCH
      // No enviar: id, floorLevel, canvasWidth, canvasHeight, gridSize, showGrid, backgroundImageUrl
      // Estos son campos de configuración que no se actualizan en cada guardado
      final updateData = {
        'name': floorPlan.name,
        'layers': floorPlan.layers.map((l) => l.toJson()).toList(),
        if (floorPlan.metadata != null) 'metadata': floorPlan.metadata,
      };

      final response = await dio.patch(
        '/floor-plans/$id',
        data: updateData,
      );
      return FloorPlan.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Error updating floor plan: ${e.message}');
    }
  }

  @override
  Future<void> deleteFloorPlan(String id) async {
    try {
      await dio.delete('/floor-plans/$id');
    } on DioException catch (e) {
      throw Exception('Error deleting floor plan: ${e.message}');
    }
  }

  @override
  Future<FloorPlan> duplicateFloorPlan(String id, String newName) async {
    try {
      final response = await dio.post(
        '/floor-plans/$id/duplicate',
        data: {'newName': newName},
      );
      return FloorPlan.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Error duplicating floor plan: ${e.message}');
    }
  }
}
