import 'package:get/get.dart';

import '../../../../core/utils/date_period.dart';
import '../../domain/entities/cash_session.dart';
import '../../domain/usecases/cash_session_usecases.dart';

/// Controller del historial de sesiones de caja.
///
/// Responsabilidades:
/// - Cargar y paginar sesiones con filtros (período + estado).
/// - Exponer totales del período (cash, otros métodos, gastos).
/// - Cargar el reporte detallado (X/Z) de una sesión seleccionada.
///
/// El detail page reutiliza este mismo controller via [Get.find] para
/// llamar [loadReport] sin duplicar la inyección de use cases.
class CashSessionHistoryController extends GetxController {
  final CashSessionUseCases useCases;
  CashSessionHistoryController({required this.useCases});

  // ── Filtros ──────────────────────────────────────────────────────────
  final Rx<DatePeriod> period = DatePeriod.thisMonth.obs;
  final Rxn<CashSessionStatus> statusFilter = Rxn<CashSessionStatus>();

  // ── Lista ────────────────────────────────────────────────────────────
  final RxList<CashSession> sessions = <CashSession>[].obs;
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  // ── Reporte de sesión individual (X / Z de caja) ─────────────────────
  final Rxn<Map<String, dynamic>> reportData = Rxn<Map<String, dynamic>>();
  final RxBool isLoadingReport = false.obs;

  // ── Totales del período (computados desde la lista) ──────────────────
  double get periodCashTotal =>
      sessions.fold(0.0, (sum, s) => sum + s.totalCashCollected);

  double get periodOtherTotal =>
      sessions.fold(0.0, (sum, s) => sum + s.totalOtherCollected);

  double get periodExpensesTotal =>
      sessions.fold(0.0, (sum, s) => sum + s.totalCashExpenses);

  double get periodNetCash =>
      sessions.fold(0.0, (sum, s) => sum + s.currentExpectedAmount);

  int get closedCount =>
      sessions.where((s) => s.isClosed).length;

  int get openCount =>
      sessions.where((s) => s.isOpen).length;

  // ── Ciclo de vida ────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    load();
  }

  // ── Acciones de filtro ───────────────────────────────────────────────
  void setPeriod(DatePeriod p) {
    if (p == period.value) return;
    period.value = p;
    load();
  }

  void toggleStatus(CashSessionStatus s) {
    statusFilter.value = (statusFilter.value == s) ? null : s;
    load();
  }

  Future<void> reload() => load();

  // ── Carga principal ──────────────────────────────────────────────────
  Future<void> load() async {
    isLoading.value = true;
    error.value = '';

    final range = resolveDatePeriod(period.value);
    final result = await useCases.findAll(
      status: statusFilter.value,
      dateFrom: range.start,
      dateTo: range.end,
    );

    result.fold(
      (failure) => error.value = failure.message,
      (list) => sessions.value = list,
    );

    isLoading.value = false;
  }

  // ── Reporte de una sesión específica ─────────────────────────────────
  Future<void> loadReport(String sessionId) async {
    reportData.value = null;
    isLoadingReport.value = true;
    final result = await useCases.getReport(sessionId);
    result.fold(
      (_) {},
      (data) => reportData.value = data,
    );
    isLoadingReport.value = false;
  }
}
