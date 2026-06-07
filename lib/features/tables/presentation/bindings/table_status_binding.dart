//lib /features/tables/presentation/bindings/table_status_binding.dart

import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../data/datasources/table_status_datasource.dart';
import '../../data/repositories/table_status_repository.dart';
import '../controllers/table_status_controller.dart';

/// Table Status Binding
/// Configura las dependencias para el módulo de estado de mesas
class TableStatusBinding extends Bindings {
  @override
  void dependencies() {
    // Registrar datasource
    Get.lazyPut<TableStatusDatasource>(
      () => TableStatusDatasourceImpl(dio: di.sl<Dio>()),
    );

    // Registrar repository
    Get.lazyPut<TableStatusRepository>(
      () => TableStatusRepositoryImpl(
        datasource: Get.find<TableStatusDatasource>(),
      ),
    );

    // Registrar controller
    Get.lazyPut<TableStatusController>(
      () =>
          TableStatusController(repository: Get.find<TableStatusRepository>()),
    );
  }
}
