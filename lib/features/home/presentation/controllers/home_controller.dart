import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/routes/navigation_service.dart';
import '../../../../core/utils/ui_access.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

/// Home Controller
///
/// Maneja el estado y lógica del Home/Dashboard.
///
/// Las estadísticas se obtienen vía Dio contra el backend; cada llamada se
/// maneja de forma independiente para que un endpoint caído no rompa todo
/// el dashboard. Si una métrica falla, queda en `0` y se loguea con
/// `debugPrint`.
class HomeController extends GetxController {
  // Observable para el índice de la navegación inferior
  final _currentIndex = 0.obs;

  // Observable para estadísticas del dashboard
  final _totalSalesToday = 0.0.obs;
  final _totalSalesYesterday = 0.0.obs;
  final _activeOrders = 0.obs;
  final _occupiedTables = 0.obs;
  final _totalTables = 0.obs;
  final _totalCustomers = 0.obs;
  final _netProfitMonth = 0.0.obs;
  final _hasProfitData = false.obs;
  final _isLoadingStats = false.obs;

  // Getters
  int get currentIndex => _currentIndex.value;
  double get totalSalesToday => _totalSalesToday.value;
  double get totalSalesYesterday => _totalSalesYesterday.value;
  int get activeOrders => _activeOrders.value;
  int get occupiedTables => _occupiedTables.value;
  int get totalTables => _totalTables.value;
  int get totalCustomers => _totalCustomers.value;
  bool get isLoadingStats => _isLoadingStats.value;

  /// Ganancia neta del mes en curso (Ingresos − COGS − Gastos − Nómina).
  /// Solo se carga para admin/manager. `hasProfitData` indica si el fetch
  /// fue exitoso (para no mostrar "$0" engañoso si el endpoint falló).
  double get netProfitMonth => _netProfitMonth.value;
  bool get hasProfitData => _hasProfitData.value;

  /// Delta porcentual de ventas vs. el día anterior.
  ///
  /// Devuelve null cuando no es comparable (sin ventas ayer y sin ventas
  /// hoy, o aún cargando) — la UI muestra "—" en vez de un número falso.
  /// Si ayer fue 0 y hoy hay ventas, mostramos solo "+nuevo".
  double? get salesDeltaVsYesterday {
    if (isLoadingStats) return null;
    final yesterday = _totalSalesYesterday.value;
    final today = _totalSalesToday.value;
    if (yesterday <= 0 && today <= 0) return null;
    if (yesterday <= 0) return double.infinity;
    return ((today - yesterday) / yesterday) * 100;
  }

  /// Texto formateado para mostrar el delta. Devuelve string vacía si no
  /// hay datos comparables.
  String get salesDeltaLabel {
    final delta = salesDeltaVsYesterday;
    if (delta == null) return 'Sin datos de ayer';
    if (delta == double.infinity) return 'Primera venta del día';
    final sign = delta >= 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(0)}% vs. ayer';
  }

  /// Mesas formateado como "ocupadas/total". Si no hay mesas
  /// registradas devuelve solo el conteo de ocupadas para no mostrar
  /// "0/0" que confunde.
  String get tablesOccupancyLabel {
    if (_totalTables.value == 0) return '${_occupiedTables.value}';
    return '${_occupiedTables.value}/${_totalTables.value}';
  }

  @override
  void onInit() {
    super.onInit();
    loadDashboardStats();
  }

  /// Cambia el índice de la navegación inferior
  void changeIndex(int index) {
    _currentIndex.value = index;
  }

  /// Carga las estadísticas del dashboard desde el backend.
  ///
  /// Se disparan las cuatro requests en paralelo (cada una en su propio
  /// `try/catch`) para no esperar serial y para que la falla de una no
  /// arrastre a las demás.
  Future<void> loadDashboardStats() async {
    _isLoadingStats.value = true;

    final dio = GetIt.I<Dio>();

    // Disparamos en paralelo: el dashboard tarda lo que tarda el endpoint
    // más lento, no la suma de todos.
    final tasks = <Future<void>>[
      _loadTotalSalesToday(dio),
      _loadTotalSalesYesterday(dio),
      _loadActiveOrders(dio),
      _loadTablesStatistics(dio),
      _loadTotalCustomers(dio),
    ];
    // La ganancia es admin/manager-only en el backend: solo la pedimos para
    // esos roles y evitamos 403 (que ensucian logs y gastan rate-limit) en
    // meseros/cajeros/cocina.
    if (_canSeeFinance) tasks.add(_loadNetProfitMonth(dio));

    await Future.wait<void>(tasks);

    _isLoadingStats.value = false;
  }

  bool get _canSeeFinance {
    try {
      return UiAccess.from(Get.find<AuthController>().currentUser)
          .canSeeFinance;
    } catch (_) {
      return false;
    }
  }

  /// Ganancia neta del mes en curso → `GET /finance/pnl`.
  Future<void> _loadNetProfitMonth(Dio dio) async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1);
      final res = await dio.get(
        '/finance/pnl',
        queryParameters: {
          'date_from': start.toUtc().toIso8601String(),
          'date_to': now.toUtc().toIso8601String(),
        },
      );
      final data = res.data;
      final body = (data is Map && data['data'] is Map)
          ? data['data'] as Map
          : (data is Map ? data : const {});
      final net = body['net_profit'];
      _netProfitMonth.value = net is num ? net.toDouble() : 0.0;
      _hasProfitData.value = true;
    } catch (e) {
      debugPrint('Error cargando ganancia del mes: $e');
      _hasProfitData.value = false;
    }
  }

  /// `total_revenue` del día → `GET /orders/statistics?date_from=...&date_to=...`.
  /// Usamos el rango [00:00, 23:59:59.999] del día local — el backend pasa el
  /// `date_to` por `<=` así que incluye toda la jornada.
  Future<void> _loadTotalSalesToday(Dio dio) async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = DateTime(
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
        999,
      );
      final res = await dio.get(
        '/orders/statistics',
        queryParameters: {
          'date_from': start.toUtc().toIso8601String(),
          'date_to': end.toUtc().toIso8601String(),
        },
      );
      final data = res.data;
      // El controlador del backend devuelve directamente
      // `{ total_orders, total_revenue, ... }`. Algunos interceptores pueden
      // envolverlo en `{ data: { ... } }`; cubrimos ambos casos.
      final body = (data is Map && data['data'] is Map)
          ? data['data'] as Map
          : (data is Map ? data : const {});
      final revenue = body['total_revenue'];
      _totalSalesToday.value = revenue is num ? revenue.toDouble() : 0.0;
    } catch (e) {
      debugPrint('Error cargando total de ventas del día: $e');
      _totalSalesToday.value = 0.0;
    }
  }

  /// Cantidad de órdenes activas → `GET /orders/active`. El endpoint devuelve
  /// el array de órdenes "no completadas y no canceladas", así que el conteo
  /// es directamente `length`.
  Future<void> _loadActiveOrders(Dio dio) async {
    try {
      final res = await dio.get('/orders/active');
      final data = res.data;
      // Soportamos respuesta como array directo o `{ data: [...] }`.
      List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['data'] is List) {
        list = data['data'] as List<dynamic>;
      } else if (data is Map && data['meta'] is Map) {
        // Fallback: algunos backends devuelven paginado con meta.total.
        final total = (data['meta'] as Map)['total'];
        _activeOrders.value = total is num ? total.toInt() : 0;
        return;
      } else {
        list = const [];
      }
      _activeOrders.value = list.length;
    } catch (e) {
      debugPrint('Error cargando órdenes activas: $e');
      _activeOrders.value = 0;
    }
  }

  /// Carga ventas del día anterior — necesario para calcular el delta
  /// "+X% vs. ayer" del hero. Antes ese valor estaba HARDCODED a "+12%"
  /// que mentía siempre. Ahora si ayer no se vendió nada, mostramos
  /// "Primera venta del día" en vez de un porcentaje falso.
  Future<void> _loadTotalSalesYesterday(Dio dio) async {
    try {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final endYesterday = DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
        23,
        59,
        59,
        999,
      );
      final res = await dio.get(
        '/orders/statistics',
        queryParameters: {
          'date_from': yesterday.toUtc().toIso8601String(),
          'date_to': endYesterday.toUtc().toIso8601String(),
        },
      );
      final data = res.data;
      final body = (data is Map && data['data'] is Map)
          ? data['data'] as Map
          : (data is Map ? data : const {});
      final revenue = body['total_revenue'];
      _totalSalesYesterday.value = revenue is num ? revenue.toDouble() : 0.0;
    } catch (e) {
      debugPrint('Error cargando ventas de ayer: $e');
      _totalSalesYesterday.value = 0.0;
    }
  }

  /// Estadísticas de mesas → `GET /tables/statistics`. El endpoint
  /// devuelve `{ total_tables, occupied, available, ... }`. Antes solo
  /// usábamos `occupied` y el total se hardcodeaba a "/12" en el
  /// dashboard — ahora venimos con `total_tables` real del backend
  /// (que a su vez se arregló para leer `table_status` en vez de la
  /// tabla legacy `tables`).
  Future<void> _loadTablesStatistics(Dio dio) async {
    try {
      final res = await dio.get('/tables/statistics');
      final data = res.data;
      final body = (data is Map && data['data'] is Map)
          ? data['data'] as Map
          : (data is Map ? data : const {});
      final occupied = body['occupied'];
      final total = body['total_tables'];
      _occupiedTables.value = occupied is num ? occupied.toInt() : 0;
      _totalTables.value = total is num ? total.toInt() : 0;
    } catch (e) {
      debugPrint('Error cargando estadísticas de mesas: $e');
      _occupiedTables.value = 0;
      _totalTables.value = 0;
    }
  }

  /// Total de clientes → `GET /customers/statistics` (devuelve
  /// `{ total_customers: N, ... }`).
  Future<void> _loadTotalCustomers(Dio dio) async {
    try {
      final res = await dio.get('/customers/statistics');
      final data = res.data;
      final body = (data is Map && data['data'] is Map)
          ? data['data'] as Map
          : (data is Map ? data : const {});
      final total = body['total_customers'];
      _totalCustomers.value = total is num ? total.toInt() : 0;
    } catch (e) {
      debugPrint('Error cargando total de clientes: $e');
      _totalCustomers.value = 0;
    }
  }

  /// Refresca las estadísticas
  Future<void> refreshStats() async {
    await loadDashboardStats();
  }

  // Estos métodos delegan a `NavigationService` para mantener una única
  // fuente de verdad sobre los nombres de rutas. Cualquier nueva ruta del
  // dashboard debe agregarse al `NavigationService`, no acá.
  void goToOrders() => NavigationService.toOrders();
  void goToProducts() => NavigationService.toProducts();
  void goToTables() => NavigationService.toTables();
  void goToCustomers() => NavigationService.toCustomers();
  void createNewOrder() => NavigationService.toCreateOrder();
}
