import 'package:get/get.dart';
import '../../domain/entities/customer_report.dart';
import '../../domain/usecases/get_customer_report_usecase.dart';

/// Customer Report Controller
///
/// Reactivo. Carga el reporte combinado (estadísticas globales + lista
/// de clientes) en una sola llamada al usecase y expone `refresh` para
/// pull-to-refresh.
class CustomerReportController extends GetxController {
  final GetCustomerReportUseCase getCustomerReportUseCase;

  CustomerReportController({required this.getCustomerReportUseCase});

  final Rx<CustomerReport> report = CustomerReport.empty().obs;
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
    final result = await getCustomerReportUseCase();
    result.fold(
      (failure) => errorMessage.value = failure.message,
      (data) => report.value = data,
    );
    isLoading.value = false;
  }

  @override
  Future<void> refresh() => load();
}
