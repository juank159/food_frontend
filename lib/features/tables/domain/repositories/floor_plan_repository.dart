// lib/features/tables/domain/repositories/floor_plan_repository.dart

import '../entities/floor_plan.dart';

abstract class FloorPlanRepository {
  Future<List<FloorPlan>> getFloorPlans();
  Future<FloorPlan> getFloorPlanById(String id);
  Future<FloorPlan> createFloorPlan(FloorPlan floorPlan);
  Future<FloorPlan> updateFloorPlan(String id, FloorPlan floorPlan);
  Future<void> deleteFloorPlan(String id);
  Future<FloorPlan> duplicateFloorPlan(String id, String newName);
}
