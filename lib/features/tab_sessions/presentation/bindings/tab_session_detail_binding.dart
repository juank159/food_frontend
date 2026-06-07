import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/tab_session_usecases.dart';
import '../controllers/tab_session_detail_controller.dart';

class TabSessionDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TabSessionDetailController>(
      () => TabSessionDetailController(
        useCases: sl<TabSessionUseCases>(),
      ),
    );
  }
}
