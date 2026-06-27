import 'dart:async';
import 'package:get/get.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/safe_get.dart';
import '../../../printer_configs/data/printing_orchestrator.dart';
import '../../data/datasources/order_remote_datasource.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_item.dart';
import '../../domain/usecases/get_order_by_id_usecase.dart';
import '../../domain/usecases/update_order_item_status_usecase.dart';
import '../../domain/usecases/update_order_status_usecase.dart';
import '../../../payments/presentation/controllers/payment_controller.dart';
import '../../../../core/utils/app_snackbar.dart';
import 'orders_controller.dart';
import 'pending_review_watcher.dart';

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

  /// IDs de items con un update en vuelo. Permite mostrar un spinner
  /// SOLO en el item tocado en vez de bloquear toda la lista.
  final RxSet<String> updatingItemIds = <String>{}.obs;

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

  /// Actualiza el estado de UN item de la orden actual. El backend
  /// mantiene los timestamps (`prepared_at`, `delivered_at`) y, cuando
  /// todos los items con preparación llegan al mismo estado, avanza la
  /// orden completa automáticamente.
  ///
  /// La UI usa esto típicamente para que el mesero marque item-por-item
  /// lo que va bajando a la mesa: el item pasa de `ready` → `delivered`
  /// y cuando todos están delivered la orden completa avanza sola.
  Future<bool> updateItemStatus({
    required String itemId,
    required OrderStatus newStatus,
  }) async {
    if (!hasOrder) return false;
    if (updatingItemIds.contains(itemId)) return false;

    // Optimistic update: mutamos el item LOCALMENTE antes de mandar
    // al backend, así la UI cambia al instante del tap. Si el backend
    // falla, restauramos la orden previa. Sin esto el usuario tenía
    // que esperar el round-trip y a veces parecía que "no respondía".
    final previousOrder = currentOrder!;
    final patchedItems = previousOrder.items.map((it) {
      if (it.id != itemId) return it;
      final now = DateTime.now();
      return OrderItem(
        id: it.id,
        orderId: it.orderId,
        productId: it.productId,
        productName: it.productName,
        unitPrice: it.unitPrice,
        quantity: it.quantity,
        subtotal: it.subtotal,
        specialInstructions: it.specialInstructions,
        customizations: it.customizations,
        modifiers: it.modifiers,
        status: newStatus,
        requiresPreparation: it.requiresPreparation,
        preparedAt: newStatus == OrderStatus.ready
            ? (it.preparedAt ?? now)
            : it.preparedAt,
        deliveredAt: newStatus == OrderStatus.delivered
            ? now
            : (newStatus == OrderStatus.ready ? null : it.deliveredAt),
        createdAt: it.createdAt,
        updatedAt: now,
      );
    }).toList();
    order.value = previousOrder.copyWith(items: patchedItems);
    order.refresh();

    updatingItemIds.add(itemId);
    try {
      final usecase = sl<UpdateOrderItemStatusUseCase>();
      final result = await usecase(
        orderId: previousOrder.id,
        itemId: itemId,
        status: newStatus,
      );
      return result.fold(
        (failure) {
          // Revertir el optimistic update
          order.value = previousOrder;
          order.refresh();
          AppSnackbar.show('No se pudo marcar el item', failure.message);
          return false;
        },
        (updatedOrder) {
          order.value = updatedOrder;
          order.refresh();
          if (Get.isRegistered<OrdersController>()) {
            Get.find<OrdersController>().applyOrderUpdate(updatedOrder);
          }
          return true;
        },
      );
    } catch (e) {
      // Fallback de seguridad por si el use case throws fuera del fold
      order.value = previousOrder;
      order.refresh();
      AppSnackbar.show('No se pudo marcar el item', e.toString());
      return false;
    } finally {
      updatingItemIds.remove(itemId);
    }
  }

  /// Marca TODOS los items pendientes como entregados de una vez.
  /// Útil cuando el mesero llega a la mesa con la bandeja entera y
  /// no quiere ir uno por uno. Llama al endpoint item-por-item para
  /// que el backend respete sus timestamps y auto-advances.
  Future<void> deliverAllPending() async {
    if (!hasOrder) return;
    final pending = currentOrder!.items
        .where((i) => !i.isDelivered)
        .map((i) => i.id)
        .toList();
    if (pending.isEmpty) return;

    for (final id in pending) {
      await updateItemStatus(itemId: id, newStatus: OrderStatus.delivered);
    }
    AppSnackbar.show(
      'Entrega registrada',
      '${pending.length} ${pending.length == 1 ? "item" : "items"} marcado(s) como entregado(s)',
    );
  }

  /// Cuántos items ya están entregados sobre el total. Lo usa la UI
  /// de la lista para el chip "X de Y entregados" y el progress bar.
  ({int delivered, int total}) get deliveryProgress {
    if (!hasOrder) return (delivered: 0, total: 0);
    final total = currentOrder!.items.length;
    final delivered =
        currentOrder!.items.where((i) => i.isDelivered).length;
    return (delivered: delivered, total: total);
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

  /// Aceptar una orden actualizada **sin ir al backend**. Lo invoca
  /// `OrdersController.applyOrderUpdate` cuando un cambio externo
  /// (cobro, status update) actualizó la orden en la lista y este
  /// detalle está abierto en la misma. Antes el detalle solo se
  /// enteraba si alguien llamaba `refresh()` manualmente y duplicaba
  /// el GET — ahora aprovechamos el order completo que ya viene del
  /// backend en el flujo principal.
  void acceptExternalUpdate(Order updated) {
    if (currentOrder?.id != updated.id) return;
    order.value = updated;
    order.refresh();
  }

  /// True si la orden actual es una self-order por QR que está
  /// esperando aprobación. La UI usa esto para mostrar el banner
  /// + botones "Aprobar/Rechazar" en lugar del card genérico de
  /// "Cambiar Estado".
  bool get isPendingReviewSelfOrder {
    if (!hasOrder) return false;
    return currentOrder!.status == OrderStatus.pendingReview &&
        currentOrder!.orderSource.isCustomerSelfOrder;
  }

  /// Aprueba la self-order (pending_review → confirmed) directamente
  /// desde el detalle. Reusa el endpoint dedicado `/approve` que ya
  /// usa la bandeja, refresca el watcher global y **auto-imprime la
  /// comanda** si hay impresora default de cocina configurada con
  /// `auto_print=true`.
  Future<void> approveSelfOrder({bool toConfirmed = true}) async {
    if (!hasOrder) return;
    final orderId = currentOrder!.id;
    final label = currentOrder!.displayTableLabel;
    isUpdatingStatus.value = true;
    try {
      await sl<OrderRemoteDataSource>().approveSelfOrder(
        orderId,
        toConfirmed: toConfirmed,
      );
      // Refrescar el badge global de pendientes (puede no estar
      // registrado si por algún motivo el watcher fue parado).
      SafeGet.run<PendingReviewWatcher>((w) => w.refreshNow());

      // Fire-and-forget: la comanda se manda a la impresora de cocina
      // si está configurada. Errores los maneja el orchestrator con
      // snackbars elegantes.
      unawaited(
        PrintingOrchestrator.autoPrintKitchen(
          orderId: orderId,
          subtitle: label,
        ),
      );

      await refresh();
      AppSnackbar.show(
        'Pedido aprobado',
        toConfirmed
            ? 'Enviado a cocina'
            : 'Listo para confirmar en el flujo normal',
      );
    } catch (e) {
      AppSnackbar.show('No se pudo aprobar', e.toString());
    } finally {
      isUpdatingStatus.value = false;
    }
  }

  /// Rechaza la self-order con razón obligatoria
  /// (pending_review → cancelled).
  Future<void> rejectSelfOrder(String reason) async {
    if (!hasOrder) return;
    if (reason.trim().length < 3) {
      AppSnackbar.show(
        'Motivo requerido',
        'Escribí brevemente por qué rechazás el pedido.',
      );
      return;
    }
    isUpdatingStatus.value = true;
    try {
      await sl<OrderRemoteDataSource>().rejectSelfOrder(
        currentOrder!.id,
        reason.trim(),
      );
      SafeGet.run<PendingReviewWatcher>((w) => w.refreshNow());
      await refresh();
      AppSnackbar.show(
        'Pedido rechazado',
        'El cliente verá el cambio en su pantalla de tracking.',
      );
    } catch (e) {
      AppSnackbar.show('No se pudo rechazar', e.toString());
    } finally {
      isUpdatingStatus.value = false;
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
      case OrderStatus.pendingReview:
        // Self-order esperando aprobación del mesero. El flujo
        // dedicado (PendingReviewPage) maneja approve/reject — desde
        // el detalle solo permitimos cancelar; aprobar va por el
        // endpoint específico.
        return [OrderStatus.cancelled];
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

  // ─────────────────────── Edición de ítems ───────────────────────

  Future<bool> addItem({
    String? productId,
    String? variantId,
    String? productName,
    double? unitPrice,
    required int quantity,
    String? specialInstructions,
    List<Map<String, dynamic>>? modifiers,
  }) async {
    final orderId = currentOrder?.id;
    if (orderId == null) return false;
    try {
      isLoading.value = true;
      final ds = sl<OrderRemoteDataSource>();
      final data = <String, dynamic>{
        if (productId != null) 'product_id': productId,
        if (variantId != null) 'variant_id': variantId,
        if (productName != null) 'product_name': productName,
        if (unitPrice != null) 'unit_price': unitPrice,
        'quantity': quantity,
        if (specialInstructions != null)
          'special_instructions': specialInstructions,
        if (modifiers != null && modifiers.isNotEmpty)
          'modifiers': modifiers,
      };
      final updated = await ds.addOrderItem(orderId, data);
      order.value = updated.toEntity();
      // Forzar emit aunque Equatable pueda considerar la orden "igual" —
      // mismo patrón que updateItemStatus y updateOrderStatus.
      order.refresh();
      if (Get.isRegistered<OrdersController>()) {
        Get.find<OrdersController>().applyOrderUpdate(order.value!);
      }
      return true;
    } catch (e) {
      AppSnackbar.show('Error al agregar', e.toString());
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> removeItem(OrderItem item) async {
    final orderId = currentOrder?.id;
    if (orderId == null) return false;

    // Optimistic: quitar item localmente al instante; si falla, revertir.
    final previousOrder = currentOrder!;
    final optimisticItems =
        previousOrder.items.where((i) => i.id != item.id).toList();
    order.value = previousOrder.copyWith(items: optimisticItems);
    order.refresh();

    try {
      updatingItemIds.add(item.id);
      final ds = sl<OrderRemoteDataSource>();
      final updated = await ds.removeOrderItem(orderId, item.id);
      order.value = updated.toEntity();
      order.refresh();
      if (Get.isRegistered<OrdersController>()) {
        Get.find<OrdersController>().applyOrderUpdate(order.value!);
      }
      return true;
    } catch (e) {
      order.value = previousOrder;
      order.refresh();
      AppSnackbar.show('Error al eliminar', e.toString());
      return false;
    } finally {
      updatingItemIds.remove(item.id);
    }
  }

  /// Reduce la cantidad de un ítem. Si `newQty` ≤ 0 elimina el ítem.
  /// Usa el endpoint PATCH /orders/:id/items/:itemId/quantity.
  Future<bool> updateItemQty(OrderItem item, int newQty) async {
    final orderId = currentOrder?.id;
    if (orderId == null) return false;

    final previousOrder = currentOrder!;

    // Optimistic: si qty llega a 0 lo quitamos; si no, lo actualizamos.
    if (newQty <= 0) {
      return removeItem(item);
    }
    final optimisticItems = previousOrder.items.map((i) {
      if (i.id != item.id) return i;
      return OrderItem(
        id: i.id,
        orderId: i.orderId,
        productId: i.productId,
        productName: i.productName,
        unitPrice: i.unitPrice,
        quantity: newQty,
        subtotal: i.unitPrice * newQty,
        specialInstructions: i.specialInstructions,
        customizations: i.customizations,
        modifiers: i.modifiers,
        status: i.status,
        requiresPreparation: i.requiresPreparation,
        preparedAt: i.preparedAt,
        deliveredAt: i.deliveredAt,
        createdAt: i.createdAt,
        updatedAt: DateTime.now(),
      );
    }).toList();
    order.value = previousOrder.copyWith(items: optimisticItems);
    order.refresh();

    try {
      updatingItemIds.add(item.id);
      final ds = sl<OrderRemoteDataSource>();
      final updated = await ds.updateOrderItemQty(orderId, item.id, newQty);
      order.value = updated.toEntity();
      order.refresh();
      if (Get.isRegistered<OrdersController>()) {
        Get.find<OrdersController>().applyOrderUpdate(order.value!);
      }
      return true;
    } catch (e) {
      order.value = previousOrder;
      order.refresh();
      AppSnackbar.show('Error al actualizar cantidad', e.toString());
      return false;
    } finally {
      updatingItemIds.remove(item.id);
    }
  }

  @override
  void onClose() {
    order.value = null;
    super.onClose();
  }
}
