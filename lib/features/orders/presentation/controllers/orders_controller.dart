import 'package:get/get.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../domain/entities/order.dart' as order_entity;
import '../../domain/usecases/create_order_usecase.dart';
import '../../domain/usecases/get_active_orders_usecase.dart';
import '../../domain/usecases/get_order_by_id_usecase.dart';
import '../../domain/usecases/get_orders_usecase.dart';
import '../../domain/usecases/update_order_status_usecase.dart';
import '../../../../core/utils/app_snackbar.dart';

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

  // View states
  final RxBool showOnlyActive = false.obs;
  final RxInt selectedTabIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
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

  /// Aplica una actualización de orden a la lista local SIN ir al backend.
  ///
  /// Lo usa `OrderDetailController` después de un `updateOrderStatus`
  /// exitoso para que la lista (`orders_page`) se entere del cambio
  /// inmediatamente — sin esto, el usuario tendría que pull-to-refresh
  /// manual al volver del detalle.
  ///
  /// Si el filtro activo es "Solo activas" y la orden pasó a un
  /// estado terminal (completed/cancelled), la sacamos de la lista
  /// para que no quede visible como "activa" siendo terminal.
  void applyOrderUpdate(order_entity.Order updated) {
    final index = orders.indexWhere((o) => o.id == updated.id);
    if (index == -1) return;

    // Si está filtrando solo activas y la orden ya no es activa,
    // sacarla de la lista. Si no, reemplazar in-place.
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

    // Actualizar selectedOrder por si es la misma
    if (selectedOrder.value?.id == updated.id) {
      selectedOrder.value = updated;
    }
  }

  /// Filtra órdenes por estado
  void filterByStatus(OrderStatus? status) {
    filterStatus.value = status;
    loadOrders();
  }

  /// Filtra órdenes por tipo
  void filterByOrderType(OrderType? orderType) {
    filterOrderType.value = orderType;
    loadOrders();
  }

  /// Filtra órdenes por estado de pago
  void filterByPaymentStatus(PaymentStatus? paymentStatus) {
    filterPaymentStatus.value = paymentStatus;
    // Aplicar filtro local ya que el backend no soporta este filtro directamente
    if (paymentStatus == null) {
      loadOrders();
    } else {
      orders.value = orders
          .where((order) => order.paymentStatus == paymentStatus)
          .toList();
    }
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

  /// Limpia todos los filtros
  void clearFilters() {
    filterStatus.value = null;
    filterOrderType.value = null;
    filterPaymentStatus.value = null;
    searchQuery.value = '';
    startDate.value = null;
    endDate.value = null;
    showOnlyActive.value = false;
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

  /// Verifica si hay filtros activos
  bool get hasActiveFilters =>
      filterStatus.value != null ||
      filterOrderType.value != null ||
      filterPaymentStatus.value != null ||
      searchQuery.value.isNotEmpty ||
      startDate.value != null ||
      endDate.value != null;

  /// Aplica el `searchQuery` localmente sobre la lista ya cargada.
  /// Buscamos en número de orden, nombre del cliente, mesa y teléfono.
  /// Búsqueda case-insensitive — el operario escribe rápido y sin
  /// formato.
  List<order_entity.Order> get filteredOrders {
    final q = searchQuery.value.trim().toLowerCase();
    if (q.isEmpty) return orders;
    return orders.where((o) {
      return o.orderNumber.toLowerCase().contains(q) ||
          (o.customerName?.toLowerCase().contains(q) ?? false) ||
          (o.customerPhone?.toLowerCase().contains(q) ?? false) ||
          (o.displayTableLabel.toLowerCase().contains(q));
    }).toList();
  }

  /// Setter del query — al ser RxString reactivo, cualquier widget que
  /// lo lea con `Obx` se rebuiltea solo.
  void setSearchQuery(String query) {
    searchQuery.value = query;
  }
}
