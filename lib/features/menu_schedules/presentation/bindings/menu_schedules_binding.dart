import 'package:get/get.dart';

import '../controllers/menu_schedules_controller.dart';

class MenuSchedulesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MenuSchedulesController>(() => MenuSchedulesController());
  }
}
