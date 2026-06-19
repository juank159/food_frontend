import 'package:get/get.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../domain/entities/order.dart' as order_entity;
import '../../domain/usecases/create_order_usecase.dart';
import '../../domain/usecases/get_active_orders_usecase.dart';
import '../../domain/usecases/get_order_by_id_usecase.dart';
import '../../domain/usecases/get_orders_usecase.dart';
import '../../domain/usecases/update_order_status_usecase.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/date_period.dart';
import '../../../tab_sessions/presentation/controllers/open_tabs_controller.dart';
import 'order_detail_controller.dart';

/// Orders Controller
/// Controlador para gestionar el estado de las órdenes
class OrdersController extends GetxController {
  final GetOrdersUseCase getOrdersUseCase;
  final GetOrderByIdUseCase getOrderByIdUseCase;
  final GetActiveOrdersUseCase getActiveOrdersUseCase;
  final CreateOrderUseCase createOrderUseCase;
  final UpdateOrderStatusUseCase updateOrderStatusUseCase;

  OrdersController({
    required this.getOrdersUseCase,
    required this.getOrderByIdUseCase,
    required this.getActiveOrdersUseCase,
    required this.createOrderUseCase,
    required this.updateOrderStatusUseCase,
  });

  // Observable states
  final RxList<order_entity.Order> orders = <order_entity.Order>[].obs;
  final RxList<order_entity.Order> activeOrders = <order_entity.Order>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final Rx<order_entity.Order?> selectedOrder = Rx<order_entity.Order?>(null);

  // Filter states
  final Rx<OrderStatus?> filterStatus = Rx<OrderStatus?>(null);
  final Rx<OrderType?> filterOrderType = Rx<OrderType?>(null);
  final Rx<PaymentStatus?> filterPaymentStatus = Rx<PaymentStatus?>(null);
  final RxString searchQuery = ''.obs;
  final Rx<DateTime?> startDate = Rx<DateTime?>(null);
  final Rx<DateTime?> endDate = Rx<DateTime?>(null);

  /// Período de fecha seleccionado en el filtro. Default = hoy.
  final Rx<DatePeriod> datePeriod = DatePeriod.today.obs;

  // View states
  final RxBool showOnlyActive = false.obs;
  final RxInt selectedTabIndex = 0.obs;

  /// Vista principal de la pantalla: 0 = "Órdenes" (lista de tickets),
  /// 1 = "Cuentas abiertas" (segmento embebido). Unifica las dos
  /// pantallas que antes estaban separadas en un solo lugar.
  final RxInt mainView = 0.obs;

  /// Cambia entre "Órdenes" y "Cuentas abiertas". Al entrar a cuentas
  /// refresca la lista de cuentas (el controller embebido es el mismo
  /// `OpenTabsController` global). Al volver a órdenes refresca la lista
  /// por si se cobró/cerró una cuenta desde el otro segmento.
  void switchMainView(int view) {
    if (mainView.value == view) return;
    mainView.value = view;
    if (view == 1) {
      if (Get.isRegistered<OpenTabsController>()) {
        Get.find<OpenTabsController>().load();
      }
    } else {
      loadOrders();
    }
  }

  @override
  void onInit() {
    super.onInit();
    // Arrancamos mostrando SOLO las órdenes de hoy — es la vista que el
    // cajero/mesero necesita el 99% del tiempo y evita traer histórico
    // pesado al abrir. El usuario puede ampliar el período desde el
    // filtro de fecha.
    _applyPeriodDates(DatePeriod.today);
    loadOrders();
  }

  /// Carga todas las órdenes con filtros
  Future<void> loadOrders({
    OrderStatus? status,
    OrderType? orderType,
    String? tableId,
    String? customerId,
    DateTime? start,
    DateTime? end,
  }) async {
    isLoading.value = true;
    errorMessage.value = '';

    final result = await getOrdersUseCase(
      status: status ?? filterStatus.value,
      orderType: orderType ?? filterOrderType.value,
      tableId: tableId,
      customerId: customerId,
      startDate: start ?? startDate.value,
      endDate: end ?? endDate.value,
    );

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        isLoading.value = false;
      },
      (ordersList) {
        orders.value = ordersList;
        isLoading.value = false;
      },
    );
  }

  /// Carga solo las órdenes activas
  Future<void> loadActiveOrders() async {
    isLoading.value = true;
    errorMessage.value = '';

    final result = await getActiveOrdersUseCase();

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        isLoading.value = false;
      },
      (ordersList) {
        activeOrders.value = ordersList;
        orders.value = ordersList;
        isLoading.value = false;
      },
    );
  }

  /// Carga los detalles de una orden
  Future<void> loadOrderDetails(String orderId) async {
    isLoading.value = true;
    errorMessage.value = '';

    final result = await getOrderByIdUseCase(orderId);

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        isLoading.value = false;
      },
      (order) {
        selectedOrder.value = order;
        isLoading.value = false;
      },
    );
  }

  /// Actualiza el estado de una orden
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    isLoading.value = true;
    errorMessage.value = '';

    final result = await updateOrderStatusUseCase(
      id: orderId,
      status: newStatus,
    );

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        isLoading.value = false;
        AppSnackbar.show(
          'Error',
          failure.message,
          snackPosition: SnackPosition.TOP,
        );
      },
      (updatedOrder) {
        // Actualizar la orden en la lista
        final index = orders.indexWhere((o) => o.id == orderId);
        if (index != -1) {
          orders[index] = updatedOrder;
        }

        // Actualizar la orden seleccionada si es la misma
        if (selectedOrder.value?.id == orderId) {
          selectedOrder.value = updatedOrder;
        }

        isLoading.value = false;

        AppSnackbar.show(
          'Éxito',
          'Estado actualizado a ${newStatus.displayName}',
          snackPosition: SnackPosition.TOP,
        );

        // Recargar órdenes activas si está en esa vista
        if (showOnlyActive.value) {
          loadActiveOrders();
        }
      },
    );
  }

  /// Aplica una actualización de orden a TODOS los lugares donde la
  /// orden vive en memoria — lista global, lista de activas, detail
  /// abierto. Es el **punto único** de sincronización tras cambios:
  /// cobros, status updates, item changes, etc.
  ///
  /// Sin esto los flujos asincrónicos (cobro desde detail, refresh
  /// post-update) actualizaban solo UNA de las listas y el usuario
  /// tenía que pull-to-refresh para ver el cambio en la otra pantalla.
  ///
  /// Si está filtrando "solo activas" y la orden pasó a estado final,
  /// la sacamos de la lista para que no quede colgada como activa.
  void applyOrderUpdate(order_entity.Order updated) {
    // 1. Lista global `orders` (la que muestra orders_page).
    final index = orders.indexWhere((o) => o.id == updated.id);
    if (index != -1) {
      if (showOnlyActive.value && updated.status.isFinal) {
        orders.removeAt(index);
      } else {
        orders[index] = updated;
        // `RxList[]=` debería disparar refresh interno, pero lo forzamos
        // explícitamente — si la nueva Order es Equatable-igual a la
        // previa (puede pasar con cambios solo en campos derivados como
        // paidAmount cuando ya estaba seteado), el Obx no repintaría.
        orders.refresh();
      }
    }

    // 2. Lista `activeOrders` — la usan ciertas vistas (dashboard,
    //    KDS, lista filtrada por activas). Si no la sincronizamos,
    //    queda con data vieja para siempre hasta que alguien llame
    //    `loadActiveOrders` manualmente.
    final activeIndex =
        activeOrders.indexWhere((o) => o.id == updated.id);
    if (activeIndex != -1) {
      if (updated.status.isFinal) {
        activeOrders.removeAt(activeIndex);
      } else {
        activeOrders[activeIndex] = updated;
        activeOrders.refresh();
      }
    }

    // 3. `selectedOrder` si apunta a la misma.
    if (selectedOrder.value?.id == updated.id) {
      selectedOrder.value = updated;
    }

    // 4. OrderDetailController si está abierto en esta orden — así
    //    el detail se sincroniza sin que el caller tenga que llamarlo
    //    manualmente (era una fuente clásica de "data vieja" si el
    //    detail se quedaba abierto tras el cambio).
    if (Get.isRegistered<OrderDetailController>()) {
      final detail = Get.find<OrderDetailController>();
      if (detail.currentOrder?.id == updated.id) {
        detail.acceptExternalUpdate(updated);
      }
    }
  }

  /// Registra una orden RECIÉN CREADA en las listas en memoria para que
  /// aparezca AL INSTANTE en el listado, sin esperar un reload manual.
  ///
  /// Resuelve el bug "creé una cuenta abierta / ticket y no aparece en
  /// Órdenes": el form de venta hacía `Get.back` pero nadie le avisaba a
  /// este controller, así que la lista quedaba vieja. Aplica a TODOS los
  /// modos (mostrador, mesa, para llevar, domicilio y cuenta abierta) —
  /// una orden de cuenta abierta es una orden como cualquier otra y debe
  /// verse acá, no solo en "Cuentas abiertas".
  void registerCreatedOrder(order_entity.Order order) {
    // Ya presente (caso raro) → solo refrescar sus datos.
    if (orders.any((o) => o.id == order.id)) {
      applyOrderUpdate(order);
      return;
    }
    // Si hay filtros server-side activos (estado/tipo), la orden nueva
    // podría no cumplirlos → recargamos para no mostrar algo inconsistente.
    if (filterStatus.value != null || filterOrderType.value != null) {
      loadOrders();
      return;
    }
    // Si el período de fechas visible NO incluye "ahora" (ej. estoy
    // viendo "ayer"), la orden nueva no corresponde a esta vista — el
    // filtro de fecha la excluye correctamente, no la insertamos.
    final now = DateTime.now();
    final afterStart =
        startDate.value == null || !now.isBefore(startDate.value!);
    final beforeEnd = endDate.value == null || !now.isAfter(endDate.value!);
    if (!afterStart || !beforeEnd) return;

    // Caso normal: insertar arriba (la lista va DESC por fecha de creación).
    orders.insert(0, order);
    if (order.isActive) activeOrders.insert(0, order);
  }

  /// Hace un GET fresco de UNA orden y aplica el resultado a todos los
  /// lugares relevantes. Es la forma "robusta" de pedirle al sistema
  /// que se entere de cambios remotos — usada típicamente después de
  /// un cobro o cambio que afectó campos derivados que no podemos
  /// calcular localmente (ej. `payment_status`, `paid_amount`, etc.).
  ///
  /// Devuelve la orden actualizada o null si el GET falló (en cuyo
  /// caso no aplicamos nada para no aplastar con datos parciales).
  Future<order_entity.Order?> reloadAndApply(String orderId) async {
    final result = await getOrderByIdUseCase(orderId);
    return result.fold(
      (_) => null,
      (order) {
        applyOrderUpdate(order);
        return order;
      },
    );
  }

  /// Filtra órdenes por estado
  void filterByStatus(OrderStatus? status) {
    filterStatus.value = status;
    loadOrders();
  }

  /// Filtra órdenes por tipo (server-side). Sale del modo "solo activas"
  /// (endpoint /active, que ignora filtros) para que el tipo tome efecto.
  void filterByOrderType(OrderType? orderType) {
    filterOrderType.value = orderType;
    if (showOnlyActive.value) showOnlyActive.value = false;
    loadOrders();
  }

  /// Filtra órdenes por estado de pago.
  ///
  /// El backend NO soporta este filtro, así que es client-side. ANTES se
  /// mutaba `orders.value = orders.where(...)`, lo que destruía la lista
  /// cargada: al combinarlo con otro filtro se perdían órdenes hasta un
  /// reload. Ahora solo guardamos el valor y el getter `filteredOrders`
  /// lo aplica como VISTA (no destructivo, combinable con búsqueda).
  void filterByPaymentStatus(PaymentStatus? paymentStatus) {
    filterPaymentStatus.value = paymentStatus;
  }

  /// Alterna el filtro de solo activos
  void toggleActiveFilter() {
    showOnlyActive.value = !showOnlyActive.value;
    if (showOnlyActive.value) {
      loadActiveOrders();
    } else {
      loadOrders();
    }
  }

  /// Establece el rango de fechas
  void setDateRange(DateTime? start, DateTime? end) {
    startDate.value = start;
    endDate.value = end;
    loadOrders();
  }

  /// Traduce un [DatePeriod] a un rango concreto (via `resolveDatePeriod`,
  /// reutilizable en otras pantallas) y lo deja en `startDate`/`endDate`
  /// SIN recargar. Lo usa `onInit` (default hoy) y `setDatePeriod`.
  void _applyPeriodDates(
    DatePeriod period, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final range = resolveDatePeriod(
      period,
      customStart: customStart,
      customEnd: customEnd,
    );
    startDate.value = range.start;
    endDate.value = range.end;
    datePeriod.value = period;
  }

  /// Cambia el período del filtro de fecha y recarga desde el backend.
  /// Para `custom` pasar [customStart] y [customEnd] (del date range picker).
  void setDatePeriod(
    DatePeriod period, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    // El filtro de fecha trabaja sobre la carga "por fechas" (loadOrders).
    // Si estábamos en "solo activas" (endpoint /active, que ignora fechas)
    // salimos de ese modo para que el período tenga efecto.
    if (showOnlyActive.value) showOnlyActive.value = false;
    _applyPeriodDates(period, customStart: customStart, customEnd: customEnd);
    loadOrders();
  }

  /// Limpia todos los filtros y vuelve al default (órdenes de hoy).
  void clearFilters() {
    filterStatus.value = null;
    filterOrderType.value = null;
    filterPaymentStatus.value = null;
    searchQuery.value = '';
    showOnlyActive.value = false;
    _applyPeriodDates(DatePeriod.today);
    loadOrders();
  }

  /// Refresca la lista de órdenes
  Future<void> refreshOrders() async {
    if (showOnlyActive.value) {
      await loadActiveOrders();
    } else {
      await loadOrders();
    }
  }

  /// Limpia la orden seleccionada
  void clearSelectedOrder() {
    selectedOrder.value = null;
  }

  /// Obtiene órdenes por estado
  List<order_entity.Order> getOrdersByStatus(OrderStatus status) {
    return orders.where((order) => order.status == status).toList();
  }

  /// Obtiene el número total de órdenes activas
  int get totalActiveOrders {
    return orders.where((order) => order.isActive).length;
  }

  /// Obtiene el número total de órdenes pendientes
  int get totalPendingOrders {
    return orders.where((order) => order.isPending).length;
  }

  /// Obtiene el número total de órdenes en preparación
  int get totalPreparingOrders {
    return orders.where((order) => order.isPreparing).length;
  }

  /// Obtiene el número total de órdenes listas
  int get totalReadyOrders {
    return orders.where((order) => order.isReady).length;
  }

  /// Obtiene el total de ventas del día
  double get totalSalesToday {
    final today = DateTime.now();
    return orders
        .where(
          (order) =>
              order.createdAt.year == today.year &&
              order.createdAt.month == today.month &&
              order.createdAt.day == today.day &&
              order.isCompleted,
        )
        .fold(0.0, (sum, order) => sum + order.totalAmount);
  }

  /// Verifica si hay órdenes cargadas
  bool get hasOrders => orders.isNotEmpty;

  /// Verifica si hay filtros activos. El período "Hoy" es el default, así
  /// que NO cuenta como filtro activo; cualquier otro período sí.
  bool get hasActiveFilters =>
      filterStatus.value != null ||
      filterOrderType.value != null ||
      filterPaymentStatus.value != null ||
      searchQuery.value.isNotEmpty ||
      datePeriod.value != DatePeriod.today;

  /// Vista filtrada sobre la lista ya cargada. Aplica, en este orden, los
  /// filtros CLIENT-SIDE (no destructivos):
  ///   1. Estado de pago (el backend no lo soporta).
  ///   2. Búsqueda por número / cliente / mesa / teléfono (case-insensitive).
  ///
  /// Los filtros server-side (fecha, estado, tipo) ya vienen aplicados en
  /// `orders` porque disparan un reload. Este getter se lee dentro de `Obx`,
  /// así que cambiar pago o búsqueda repinta la lista sin volver al backend.
  List<order_entity.Order> get filteredOrders {
    Iterable<order_entity.Order> result = orders;

    final pay = filterPaymentStatus.value;
    if (pay != null) {
      result = result.where((o) => o.paymentStatus == pay);
    }

    final q = searchQuery.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((o) {
        return o.orderNumber.toLowerCase().contains(q) ||
            (o.customerName?.toLowerCase().contains(q) ?? false) ||
            (o.customerPhone?.toLowerCase().contains(q) ?? false) ||
            (o.displayTableLabel.toLowerCase().contains(q));
      });
    }

    return result.toList();
  }

  /// Cantidad de filtros avanzados activos: estado (estado puntual o
  /// "solo activas" cuentan como 1), tipo de orden y estado de pago. Lo
  /// usa el badge del botón "Filtros". El período NO cuenta (se ve en su
  /// propio pill) ni la búsqueda (tiene su propio campo).
  int get advancedFilterCount =>
      ((filterStatus.value != null || showOnlyActive.value) ? 1 : 0) +
      (filterOrderType.value != null ? 1 : 0) +
      (filterPaymentStatus.value != null ? 1 : 0);

  /// Limpia los filtros avanzados (estado, "solo activas", tipo de orden y
  /// estado de pago), preservando período de fecha y búsqueda. Lo usan el
  /// botón "Limpiar" del sheet y los chips de filtros activos.
  void clearAdvancedFilters() {
    // ¿Algún filtro server-side activo? (status / tipo / modo activas)
    final hadServerFilter = filterStatus.value != null ||
        filterOrderType.value != null ||
        showOnlyActive.value;
    filterStatus.value = null;
    filterOrderType.value = null;
    filterPaymentStatus.value = null;
    showOnlyActive.value = false;
    // status/tipo son server-side → recargar por fechas. El pago es
    // client-side (lo aplica `filteredOrders`), no necesita reload.
    if (hadServerFilter) loadOrders();
  }

  /// Setter del query — al ser RxString reactivo, cualquier widget que
  /// lo lea con `Obx` se rebuiltea solo.
  void setSearchQuery(String query) {
    searchQuery.value = query;
  }
}
