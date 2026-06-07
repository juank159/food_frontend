import 'package:get/get.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../domain/entities/order.dart';
import '../../domain/usecases/get_order_by_id_usecase.dart';
import '../../domain/usecases/update_order_status_usecase.dart';
import '../../../payments/presentation/controllers/payment_controller.dart';
import '../../../../core/utils/app_snackbar.dart';
import 'orders_controller.dart';

/// Order Detail Controller
/// Controller para gestionar el detalle de una orden individual
class OrderDetailController extends GetxController {
  final GetOrderByIdUseCase getOrderByIdUseCase;
  final UpdateOrderStatusUseCase updateOrderStatusUseCase;

  OrderDetailController({
    required this.getOrderByIdUseCase,
    required this.updateOrderStatusUseCase,
  });

  // Observable state
  final Rx<Order?> order = Rx<Order?>(null);
  final RxBool isLoading = false.obs;
  final Rx<String?> errorMessage = Rx<String?>(null);
  final RxBool isUpdatingStatus = false.obs;

  // Getters
  bool get hasOrder => order.value != null;
  Order? get currentOrder => order.value;

  bool get canProcessPayment =>
      hasOrder && currentOrder!.isActive && !currentOrder!.isPaymentCompleted;

  bool get canUpdateStatus =>
      hasOrder && currentOrder!.isActive && !isUpdatingStatus.value;

  bool get canCancel =>
      hasOrder && currentOrder!.isActive && !currentOrder!.isCancelled;

  /// Carga una orden por ID
  Future<void> loadOrder(String orderId) async {
    try {
      isLoading.value = true;
      errorMessage.value = null;

      final result = await getOrderByIdUseCase(orderId);

      result.fold(
        (failure) {
          errorMessage.value = failure.message;
          AppSnackbar.show(
            'Error',
            failure.message,
            snackPosition: SnackPosition.TOP,
          );
        },
        (loadedOrder) {
          order.value = loadedOrder;
          // Forzar emit aunque Equatable considere la orden "igual" —
          // los Obx que dependen de campos derivados (paidAmount,
          // hasPartialPayment) deben repintar incluso si props no
          // detectó la diferencia por algún edge case.
          order.refresh();

          // Cargar pagos de esta orden
          final paymentController = Get.find<PaymentController>();
          paymentController.loadPaymentsByOrder(orderId);

          // Propagar a la lista para que al volver vea el estado fresco
          // (payment_status, paid_amount, etc.) sin pull-to-refresh
          // manual. Esto cubre TODOS los flujos que recargan el detalle:
          // cobro full, parcial, refund, status change, edición items.
          if (Get.isRegistered<OrdersController>()) {
            Get.find<OrdersController>().applyOrderUpdate(loadedOrder);
          }
        },
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Actualiza el estado de la orden y notifica a la lista de
  /// órdenes (`OrdersController`) para refresh automático.
  ///
  /// Sin la notificación, el usuario tendría que hacer pull-to-refresh
  /// manual al volver del detalle para ver el nuevo estado en la lista.
  Future<void> updateOrderStatus(OrderStatus newStatus) async {
    if (!canUpdateStatus) return;

    try {
      isUpdatingStatus.value = true;
      errorMessage.value = null;

      final result = await updateOrderStatusUseCase(
        id: currentOrder!.id,
        status: newStatus,
      );

      result.fold(
        (failure) {
          errorMessage.value = failure.message;
          AppSnackbar.show(
            'Error',
            failure.message,
            snackPosition: SnackPosition.TOP,
          );
        },
        (updatedOrder) {
          // 1. Actualizar el state local del detalle.
          //
          //    `Order` extiende `Equatable`, así que `Rx<T>.value = x`
          //    NO dispara los Obx si Equatable considera que el valor
          //    nuevo es "igual" al viejo (puede pasar si algunos
          //    timestamps no están en props, etc.). Llamamos
          //    `refresh()` explícitamente para FORZAR la notificación
          //    a todos los `Obx` que dependen de `order.value`. Este
          //    fue el bug que vimos: cambiabas a "preparing" y el
          //    header del detalle no cambiaba de color.
          order.value = updatedOrder;
          order.refresh();

          // 2. Notificar a la lista de órdenes para que se entere
          //    sin pull-to-refresh manual. `Get.isRegistered` evita
          //    crash si la lista no está montada (ej. detalle abierto
          //    por deep link).
          if (Get.isRegistered<OrdersController>()) {
            Get.find<OrdersController>().applyOrderUpdate(updatedOrder);
          }

          AppSnackbar.show(
            'Estado actualizado',
            newStatus.displayName,
            snackPosition: SnackPosition.TOP,
          );

          // 3. Salvavidas: si por algún motivo el `updatedOrder` del
          //    response no quedó con el status esperado (ej. el
          //    backend solo confirma sin devolver el order completo,
          //    o el modelo perdió un campo en el parse), recargamos
          //    desde el backend en background. La UI ya se actualizó
          //    arriba; este reload es para asegurar consistencia.
          if (updatedOrder.status != newStatus) {
            loadOrder(updatedOrder.id);
          }
        },
      );
    } finally {
      isUpdatingStatus.value = false;
    }
  }

  /// Muestra el dialog de pago
  /// La lógica del dialog está en OrderDetailPage para acceder al contexto
  void showPaymentDialog() {
    // Este método será llamado desde la UI
  }

  /// Refresca los datos de la orden
  @override
  Future<void> refresh() async {
    if (hasOrder) {
      await loadOrder(currentOrder!.id);
    }
  }

  /// Obtiene los estados disponibles para transición SEGÚN el tipo
  /// de orden.
  ///
  /// **Diseño de flujos simplificados** (decisión consciente para que
  /// el operario tenga menos clicks por orden):
  ///
  ///   * **dine-in / takeaway:** `pending → preparing → ready →
  ///     completed`. Sin `confirmed` (redundante, la orden ya es
  ///     válida al crearse) y sin `delivered` (no hay driver).
  ///
  ///   * **delivery:** `pending → preparing → ready → delivered →
  ///     completed`. Mantiene `delivered` porque sí hay un driver
  ///     que entrega físicamente.
  ///
  /// **Atajo "Completar ahora"** disponible desde cualquier estado
  /// activo previo a `completed`/`cancelled` — para órdenes simples
  /// (un café, una bebida) donde no tiene sentido pasar por los
  /// pasos intermedios.
  ///
  /// **Cancelar** disponible en pending/preparing/ready. NO en
  /// delivered (ya está físicamente afuera) ni en estados terminales.
  List<OrderStatus> getAvailableStatusTransitions() {
    if (!hasOrder) return [];

    final current = currentOrder!.status;
    final isDelivery = currentOrder!.orderType == OrderType.delivery;

    switch (current) {
      case OrderStatus.pending:
      case OrderStatus.confirmed:
        // `confirmed` se trata igual que `pending` para órdenes que
        // ya estén en ese estado por flujos viejos.
        return [
          OrderStatus.preparing,
          OrderStatus.completed, // atajo "Completar ahora"
          OrderStatus.cancelled,
        ];
      case OrderStatus.preparing:
        return [
          OrderStatus.ready,
          OrderStatus.completed,
          OrderStatus.cancelled,
        ];
      case OrderStatus.ready:
        if (isDelivery) {
          return [
            OrderStatus.delivered,
            OrderStatus.completed, // por si entrega + cobro en sitio
            OrderStatus.cancelled,
          ];
        }
        // dine-in / takeaway: directo a completed
        return [OrderStatus.completed, OrderStatus.cancelled];
      case OrderStatus.delivered:
        return [OrderStatus.completed];
      case OrderStatus.completed:
      case OrderStatus.cancelled:
        return [];
    }
  }

  @override
  void onClose() {
    order.value = null;
    super.onClose();
  }
}
