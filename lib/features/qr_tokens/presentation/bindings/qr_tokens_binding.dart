import 'package:get/get.dart';

import '../controllers/qr_tokens_controller.dart';

class QrTokensBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<QrTokensController>(() => QrTokensController());
  }
}
