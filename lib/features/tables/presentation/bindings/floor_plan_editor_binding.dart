// lib/features/tables/presentation/bindings/floor_plan_editor_binding.dart

import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../../core/di/injection_container.dart' as di;
import '../../data/datasources/floor_plan_datasource.dart';
import '../../data/repositories/floor_plan_repository_impl.dart';
import '../../domain/repositories/floor_plan_repository.dart';
import '../controllers/floor_plan_editor_controller.dart';

class FloorPlanEditorBinding extends Bindings {
  @override
  void dependencies() {
    // DataSource
    Get.lazyPut<FloorPlanDataSource>(
      () => FloorPlanDataSourceImpl(dio: di.sl<Dio>()),
    );

    // Repository
    Get.lazyPut<FloorPlanRepository>(
      () =>
          FloorPlanRepositoryImpl(dataSource: Get.find<FloorPlanDataSource>()),
    );

    // Controller
    Get.lazyPut<FloorPlanEditorController>(
      () => FloorPlanEditorController(
        repository: Get.find<FloorPlanRepository>(),
      ),
    );
  }
}
