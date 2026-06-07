import 'package:get/get.dart';
import '../controllers/reports_controller.dart';

/// Reports Hub Binding
///
/// El hub de reportes no consume datos remotos — sólo renderiza un grid
/// de cards estáticas que navegan a los sub-reportes. Por eso registra
/// únicamente el controller stub.
class ReportsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ReportsController>(() => ReportsController());
  }
}
