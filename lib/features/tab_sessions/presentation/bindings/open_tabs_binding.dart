import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/tab_session_usecases.dart';
import '../controllers/open_tabs_controller.dart';

class OpenTabsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<OpenTabsController>(
      () => OpenTabsController(useCases: sl<TabSessionUseCases>()),
    );
  }
}
