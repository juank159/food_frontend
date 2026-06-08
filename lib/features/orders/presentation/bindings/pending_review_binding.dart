import 'package:get/get.dart';

import '../controllers/pending_review_controller.dart';

class PendingReviewBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PendingReviewController>(() => PendingReviewController());
  }
}
