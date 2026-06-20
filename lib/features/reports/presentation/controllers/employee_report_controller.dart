import 'package:get/get.dart';
import '../../domain/entities/employee_report.dart';
import '../../domain/usecases/get_employee_report_usecase.dart';

/// Employee Report Controller
///
/// Reactivo. Carga el reporte una vez al entrar y soporta `refresh`.
/// El reporte cruza el roster (`GET /users`) con las ventas reales del mes
/// por empleado (`GET /finance/employee-sales`) — ver el datasource.
class EmployeeReportController extends GetxController {
  final GetEmployeeReportUseCase getEmployeeReportUseCase;

  EmployeeReportController({required this.getEmployeeReportUseCase});

  final Rx<EmployeeReport> report = EmployeeReport.empty().obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = '';
    final result = await getEmployeeReportUseCase();
    result.fold(
      (failure) => errorMessage.value = failure.message,
      (data) => report.value = data,
    );
    isLoading.value = false;
  }

  @override
  Future<void> refresh() => load();
}
