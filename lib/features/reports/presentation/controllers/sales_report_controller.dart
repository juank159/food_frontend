import 'package:get/get.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../orders/domain/entities/order.dart' as order_entity;
import '../../../orders/domain/usecases/get_orders_usecase.dart';
import '../../domain/entities/sales_report.dart';
import '../../domain/usecases/get_sales_report_usecase.dart';

/// Presets de rango de fechas que ofrece la pantalla de Ventas.
enum SalesRangePreset {
  today,
  last7Days,
  last30Days,
  custom,
}

/// Sales Report Controller
///
/// Reactivo. Mantiene el rango activo (`preset` + `dateFrom`/`dateTo`)
/// y dispara dos llamados en paralelo cada vez que cambia:
///
///   1) `GET /orders/statistics` → KPIs (total, ticket promedio, etc).
///   2) `GET /orders` con el rango → lista de órdenes para mostrar abajo.
///
/// Reusa `GetOrdersUseCase` del módulo de órdenes para la lista, evitando
/// duplicar lógica de paginación/serialización.
class SalesReportController extends GetxController {
  final GetSalesReportUseCase getSalesReportUseCase;
  final GetOrdersUseCase getOrdersUseCase;

  SalesReportController({
    required this.getSalesReportUseCase,
    required this.getOrdersUseCase,
  });

  /// Reporte agregado (KPIs).
  final Rx<SalesReport> report = SalesReport.empty().obs;

  /// Lista de órdenes del rango (para la sección inferior de la página).
  final RxList<order_entity.Order> orders = <order_entity.Order>[].obs;

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // Rango activo
  final Rx<SalesRangePreset> preset = SalesRangePreset.today.obs;
  final Rx<DateTime?> dateFrom = Rx<DateTime?>(null);
  final Rx<DateTime?> dateTo = Rx<DateTime?>(null);

  @override
  void onInit() {
    super.onInit();
    selectPreset(SalesRangePreset.today);
  }

  /// Cambia al preset indicado y dispara la recarga. Para `custom` se
  /// debe usar `selectCustomRange` (este método sólo aplica los presets
  /// enlatados).
  void selectPreset(SalesRangePreset newPreset) {
    if (newPreset == SalesRangePreset.custom) {
      preset.value = newPreset;
      // No tocamos las fechas — las setea `selectCustomRange`.
      return;
    }
    preset.value = newPreset;
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    switch (newPreset) {
      case SalesRangePreset.today:
        dateFrom.value = DateTime(now.year, now.month, now.day);
        dateTo.value = endOfToday;
        break;
      case SalesRangePreset.last7Days:
        dateFrom.value = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6));
        dateTo.value = endOfToday;
        break;
      case SalesRangePreset.last30Days:
        dateFrom.value = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 29));
        dateTo.value = endOfToday;
        break;
      case SalesRangePreset.custom:
        break;
    }
    load();
  }

  /// Aplica un rango custom (fin de día se normaliza a 23:59:59 para
  /// que el backend incluya órdenes creadas durante el día final).
  void selectCustomRange(DateTime from, DateTime to) {
    preset.value = SalesRangePreset.custom;
    dateFrom.value = DateTime(from.year, from.month, from.day);
    dateTo.value = DateTime(to.year, to.month, to.day, 23, 59, 59);
    load();
  }

  /// Carga el reporte y la lista de órdenes en paralelo.
  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = '';

    final from = dateFrom.value;
    final to = dateTo.value;

    final results = await Future.wait([
      getSalesReportUseCase(dateFrom: from, dateTo: to),
      getOrdersUseCase(startDate: from, endDate: to, limit: 50),
    ]);

    final reportResult = results[0];
    final ordersResult = results[1];

    reportResult.fold(
      (failure) => errorMessage.value = failure.message,
      (data) => report.value = data as SalesReport,
    );

    ordersResult.fold(
      (failure) {
        // Si ya tenemos error del reporte, no lo pisamos.
        if (errorMessage.value.isEmpty) {
          errorMessage.value = failure.message;
        }
      },
      (list) => orders.value = (list as List<order_entity.Order>),
    );

    isLoading.value = false;
  }

  @override
  Future<void> refresh() => load();

  /// Etiqueta legible del rango activo (para el subtítulo del header).
  String get rangeLabel {
    final from = dateFrom.value;
    final to = dateTo.value;
    if (from == null || to == null) return 'Sin filtro';
    if (preset.value == SalesRangePreset.today) return 'Hoy';
    if (preset.value == SalesRangePreset.last7Days) {
      return 'Últimos 7 días';
    }
    if (preset.value == SalesRangePreset.last30Days) {
      return 'Últimos 30 días';
    }
    return '${_short(from)} – ${_short(to)}';
  }

  String _short(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }

  /// Cantidad de órdenes en cada estado conocido (para chips secundarios).
  int countByStatus(OrderStatus status) =>
      report.value.byStatus[status.value] ?? 0;
}
