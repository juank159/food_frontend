import 'package:get/get.dart';

import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/shift_usecases.dart';
import '../controllers/shift_controller.dart';

class ShiftBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ShiftController>(
      () => ShiftController(useCases: sl<ShiftUseCases>()),
    );
  }
}
