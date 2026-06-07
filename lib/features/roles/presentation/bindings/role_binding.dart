import 'package:get/get.dart';

import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/role_usecases.dart';
import '../controllers/role_controller.dart';

class RoleBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RoleController>(
      () => RoleController(useCases: sl<RoleUseCases>()),
    );
  }
}
