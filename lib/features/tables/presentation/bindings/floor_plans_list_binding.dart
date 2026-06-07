// lib/features/tables/presentation/bindings/floor_plans_list_binding.dart

import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../data/datasources/floor_plan_datasource.dart';
import '../../data/repositories/floor_plan_repository_impl.dart';
import '../../domain/repositories/floor_plan_repository.dart';
import '../controllers/floor_plans_list_controller.dart';

class FloorPlansListBinding extends Bindings {
  @override
  void dependencies() {
    // Registrar datasource (si no está registrado)
    if (!Get.isRegistered<FloorPlanDataSource>()) {
      Get.lazyPut<FloorPlanDataSource>(
        () => FloorPlanDataSourceImpl(dio: di.sl<Dio>()),
      );
    }

    // Registrar repository (si no está registrado)
    if (!Get.isRegistered<FloorPlanRepository>()) {
      Get.lazyPut<FloorPlanRepository>(
        () => FloorPlanRepositoryImpl(
          dataSource: Get.find<FloorPlanDataSource>(),
        ),
      );
    }

    // Registrar controller
    Get.lazyPut<FloorPlansListController>(
      () => FloorPlansListController(
        repository: Get.find<FloorPlanRepository>(),
      ),
    );
  }
}
