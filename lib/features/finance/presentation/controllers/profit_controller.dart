import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/utils/api_response_utils.dart';
import '../../../../core/utils/date_period.dart';
import 'expenses_controller.dart' show moneyToDouble;

/// Estado de resultados (P&L) de un período.
class ProfitController extends GetxController {
  late final Dio _dio;

  final RxDouble revenue = 0.0.obs;
  final RxInt ordersCount = 0.obs;
  final RxDouble cogs = 0.0.obs;
  final RxDouble grossProfit = 0.0.obs;
  final RxDouble expensesTotal = 0.0.obs;
  final RxMap<String, double> expensesByCategory = <String, double>{}.obs;
  final RxDouble payrollTotal = 0.0.obs;
  final RxDouble netProfit = 0.0.obs;
  final RxDouble grossMarginPct = 0.0.obs;
  final RxDouble netMarginPct = 0.0.obs;

  final Rx<DatePeriod> period = DatePeriod.thisMonth.obs;
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  /// True si el negocio gana en el período.
  bool get isProfit => netProfit.value >= 0;

  @override
  void onInit() {
    super.onInit();
    _dio = GetIt.I<Dio>();
    load();
  }

  void setPeriod(DatePeriod p) {
    if (p == period.value) return;
    period.value = p;
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = '';
    try {
      final range = resolveDatePeriod(
        period.value == DatePeriod.all ? DatePeriod.thisMonth : period.value,
      );
      final qp = <String, dynamic>{
        'date_from': (range.start ?? DateTime(2000))
            .toUtc()
            .toIso8601String(),
        'date_to': (range.end ?? DateTime.now()).toUtc().toIso8601String(),
      };
      final res = await _dio.get('/finance/pnl', queryParameters: qp);
      final obj = ApiResponseUtils.object(res);
      revenue.value = moneyToDouble(obj['revenue']);
      ordersCount.value = (obj['orders_count'] as num?)?.toInt() ?? 0;
      cogs.value = moneyToDouble(obj['cogs']);
      grossProfit.value = moneyToDouble(obj['gross_profit']);
      expensesTotal.value = moneyToDouble(obj['expenses_total']);
      payrollTotal.value = moneyToDouble(obj['payroll_total']);
      netProfit.value = moneyToDouble(obj['net_profit']);
      grossMarginPct.value = moneyToDouble(obj['gross_margin_pct']);
      netMarginPct.value = moneyToDouble(obj['net_margin_pct']);
      final cats = (obj['expenses_by_category'] as Map?) ?? const {};
      expensesByCategory.value = cats.map(
        (k, v) => MapEntry(k.toString(), moneyToDouble(v)),
      );
    } catch (e) {
      error.value =
          ApiResponseUtils.errorMessage(e) ?? 'Error al cargar ganancias';
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Future<void> refresh() => load();
}
