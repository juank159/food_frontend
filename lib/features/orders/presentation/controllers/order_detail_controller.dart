import 'dart:async';
import 'package:get/get.dart';
import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/services/offline_queue_service.dart';
import '../../../../core/utils/safe_get.dart';
import '../../../printer_configs/data/printing_orchestrator.dart';
import '../../data/datasources/order_local_datasource.dart';
import '../../data/datasources/order_remote_datasource.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_item.dart';
import '../../domain/usecases/get_order_by_id_usecase.dart';
import '../../domain/usecases/update_order_item_status_usecase.dart';
import '../../domain/usecases/update_order_status_usecase.dart';
import '../../domain/usecases/update_order_usecase.dart';
import '../../../payments/presentation/controllers/payment_controller.dart';
import '../../../../core/utils/app_snackbar.dart';
import 'orders_controller.dart';
import 'pending_review_watcher.dart';

/// Order Detail Controller
/// Controller para gestionar el detalle de una orden individual
///
/// **Offline**: todas las mutaciones de esta pantalla (cambiar
/// estado, marcar un item, agregar/quitar/editar cantidad de un item,
/// editar cliente) operan sobre una orden que YA existe con id real
/// — nunca generan un id nuevo que algo más vaya a referenciar antes
/// de sincronizar. Por eso, sin conexión, se aplican OPTIMISTAS
/// localmente (ya existía ese patrón) y además se ENCOLAN para
/// cuando vuelva la señal, en vez de revertir el cambio — así el
/// usuario puede seguir llevando el control de sus órdenes (qué le
/// debe cada cliente, qué falta entregar) aunque se caiga el
/// internet. Ver `enqueueGenericMutation`.
class OrderDetailController extends GetxController {
  final GetOrderByIdUseCase getOrderByIdUseCase;
  final UpdateOrderStatusUseCase updateOrderStatusUseCase;
  final NetworkInfo networkInfo;
  final OfflineQueueService offlineQueue;
  final OrderLocalDataSource orderLocalDataSource;

  OrderDetailController({
    required this.getOrderByIdUseCase,
    required this.updateOrderStatusUseCase,
    required this.networkInfo,
    required this.offlineQueue,
    required this.orderLocalDataSource,
  });

  /// Recalcula `subtotal`/`totalAmount` por DELTA al cambiar los items
  /// localmente (agregar/quitar/editar cantidad) sin conexión — no
  /// reproduce la lógica completa de impuestos/propina/descuento del
  /// backend, solo desplaza los totales por la diferencia de items
  /// para que el preview offline sea razonable. El backend recalcula
  /// el valor REAL y lo reemplaza en cuanto sincroniza.
  Order _withRecalculatedTotals(Order base, List<OrderItem> newItems) {
    final oldItemsSum = base.items.fold<double>(0, (s, i) => s + i.subtotal);
    final newItemsSum = newItems.fold<double>(0, (s, i) => s + i.subtotal);
    final delta = newItemsSum - oldItemsSum;
    return base.copyWith(
      items: newItems,
      subtotal: base.subtotal + delta,
      totalAmount: base.totalAmount + delta,
      updatedAt: DateTime.now(),
    );
  }

  /// Mensaje consistente para toda mutación que quedó encolada —
  /// mismo texto en las 6 pantallas que pueden mutar una orden.
  void _showQueuedSnackbar() {
    AppSnackbar.show(
      'Guardado sin conexión',
      'Se va a enviar al servidor cuando vuelva la señal.',
      snackPosition: SnackPosition.TOP,
    );
  }

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

  /// Carga una orden por ID.
  ///
  /// Bug real reportado (optimización pedida): esta pantalla SIEMPRE
  /// esperaba a la red, sin pintar nada mientras tanto — a diferencia
  /// de los 3 listados (Órdenes/Productos/Cuentas abiertas), que ya
  /// pintan desde caché al instante y la red reemplaza atrás. La
  /// lista de Órdenes YA cachea cada orden completa (con items) vía
  /// `OrderLocalDataSource.peekCachedOrders` — reusamos esa misma
  /// caché acá en vez de crear un cache nuevo por-detalle: si la
  /// orden que se abre ya estaba en esa lista cacheada, se pinta de
  /// una (sin spinner) mientras la red trae la versión fresca atrás.
  Future<void> loadOrder(String orderId) async {
    try {
      final cachedList = await orderLocalDataSource.peekCachedOrders();
      final cached = cachedList
          ?.firstWhereOrNull((o) => o.id == orderId)
          ?.toEntity();
      final paintedFromCache = cached != null;
      if (paintedFromCache) {
        order.value = cached;
        order.refresh();
      }

      isLoading.value = !paintedFromCache;
      errorMessage.value = null;

      final result = await getOrderByIdUseCase(orderId);

      result.fold(
        (failure) {
          // Si ya había algo pintado desde caché (ej. sin conexión),
          // no molestamos con un error — el operario sigue viendo la
          // orden, aunque no sea la versión más fresca. Mismo criterio
          // que `OpenTabsController.load`.
          if (paintedFromCache) return;
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

    if (!await networkInfo.isConnected) {
      final optimistic = currentOrder!.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );
      order.value = optimistic;
      order.refresh();
      if (Get.isRegistered<OrdersController>()) {
        Get.find<OrdersController>().applyOrderUpdate(optimistic);
      }
      await orderLocalDataSource.updateCachedOrder(optimistic);
      await enqueueGenericMutation(
        offlineQueue,
        method: 'PATCH',
        path: ApiConstants.orderStatus(optimistic.id),
        body: {'status': newStatus.value},
      );
      _showQueuedSnackbar();
      return;
    }

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
    final optimisticOrder = previousOrder.copyWith(items: patchedItems);
    order.value = optimisticOrder;
    order.refresh();

    if (!await networkInfo.isConnected) {
      if (Get.isRegistered<OrdersController>()) {
        Get.find<OrdersController>().applyOrderUpdate(optimisticOrder);
      }
      await orderLocalDataSource.updateCachedOrder(optimisticOrder);
      await enqueueGenericMutation(
        offlineQueue,
        method: 'PATCH',
        path: '/orders/${previousOrder.id}/items/$itemId/status',
        body: {'status': newStatus.value},
      );
      _showQueuedSnackbar();
      return true;
    }

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
          // Preservar el orden original de ítems para que chulear un
          // producto no lo mueva de posición en la lista.
          final idToIndex = {
            for (var i = 0; i < previousOrder.items.length; i++)
              previousOrder.items[i].id: i,
          };
          final sorted = [...updatedOrder.items]
            ..sort(
              (a, b) =>
                  (idToIndex[a.id] ?? 9999).compareTo(idToIndex[b.id] ?? 9999),
            );
          final stableOrder = updatedOrder.copyWith(items: sorted);
          order.value = stableOrder;
          order.refresh();
          if (Get.isRegistered<OrdersController>()) {
            Get.find<OrdersController>().applyOrderUpdate(stableOrder);
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
    // Un descuento no se entrega: no cuenta en el avance de entregas.
    final products = currentOrder!.items.where((i) => i.unitPrice >= 0);
    final total = products.length;
    final delivered = products.where((i) => i.isDelivered).length;
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

    final data = <String, dynamic>{
      if (productId != null) 'product_id': productId,
      if (variantId != null) 'variant_id': variantId,
      if (productName != null) 'product_name': productName,
      if (unitPrice != null) 'unit_price': unitPrice,
      'quantity': quantity,
      if (specialInstructions != null)
        'special_instructions': specialInstructions,
      if (modifiers != null && modifiers.isNotEmpty) 'modifiers': modifiers,
    };

    if (!await networkInfo.isConnected) {
      final previousOrder = currentOrder!;
      final now = DateTime.now();
      final optimisticItem = OrderItem(
        id: 'local_${now.microsecondsSinceEpoch}',
        orderId: orderId,
        productId: productId ?? '',
        // Sin productId (item libre) siempre viene productName; con
        // productId puede faltar si el caller no lo resolvió — el
        // backend lo completa al sincronizar.
        productName: productName ?? 'Producto',
        unitPrice: unitPrice ?? 0,
        quantity: quantity,
        subtotal: (unitPrice ?? 0) * quantity,
        specialInstructions: specialInstructions,
        createdAt: now,
        updatedAt: now,
      );
      final optimisticOrder = _withRecalculatedTotals(previousOrder, [
        ...previousOrder.items,
        optimisticItem,
      ]);
      order.value = optimisticOrder;
      order.refresh();
      if (Get.isRegistered<OrdersController>()) {
        Get.find<OrdersController>().applyOrderUpdate(optimisticOrder);
      }
      await orderLocalDataSource.updateCachedOrder(optimisticOrder);
      await enqueueGenericMutation(
        offlineQueue,
        method: 'POST',
        path: '/orders/$orderId/items',
        body: data,
        // Permite deshacer esto si el usuario borra este MISMO item
        // antes de reconectar — ver removeItem().
        clientRef: optimisticItem.id,
      );
      _showQueuedSnackbar();
      return true;
    }

    try {
      isLoading.value = true;
      final ds = sl<OrderRemoteDataSource>();
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
    final optimisticItems = previousOrder.items
        .where((i) => i.id != item.id)
        .toList();
    final optimisticOrder = _withRecalculatedTotals(
      previousOrder,
      optimisticItems,
    );
    order.value = optimisticOrder;
    order.refresh();

    final isLocalOnlyItem = item.id.startsWith('local_');

    if (!await networkInfo.isConnected || isLocalOnlyItem) {
      if (Get.isRegistered<OrdersController>()) {
        Get.find<OrdersController>().applyOrderUpdate(optimisticOrder);
      }
      await orderLocalDataSource.updateCachedOrder(optimisticOrder);
      // Si el item en sí se había agregado offline y todavía no
      // sincronizó, deshacemos directamente ese "addItem" encolado —
      // no tiene sentido mandar un DELETE de algo que el servidor
      // nunca llegó a crear.
      final undone = isLocalOnlyItem
          ? await removeQueuedMutationByClientRef(offlineQueue, item.id)
          : false;
      if (!undone && !isLocalOnlyItem) {
        await enqueueGenericMutation(
          offlineQueue,
          method: 'DELETE',
          path: '/orders/$orderId/items/${item.id}',
        );
        _showQueuedSnackbar();
      }
      return true;
    }

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
        // Optimista: el backend recalcula el valor real (ver
        // OrdersService.updateItemQuantity) — acá solo evitamos que el
        // preview local muestre el total sin los extras mientras
        // llega la respuesta real.
        subtotal: i.unitPrice * newQty + i.modifiersTotal * newQty,
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
    // Para la rama online se conserva el comportamiento histórico (no
    // recalcula totales, confía en la respuesta real del backend). Para
    // la rama offline sí recalculamos — no hay respuesta del backend
    // que vaya a corregir el preview hasta que sincronice, y el usuario
    // necesita ver cuánto debe el cliente ahora mismo (sin internet).
    final isOffline = !await networkInfo.isConnected;
    final optimisticOrder = isOffline
        ? _withRecalculatedTotals(previousOrder, optimisticItems)
        : previousOrder.copyWith(items: optimisticItems);
    order.value = optimisticOrder;
    order.refresh();

    if (item.id.startsWith('local_') || isOffline) {
      if (Get.isRegistered<OrdersController>()) {
        Get.find<OrdersController>().applyOrderUpdate(optimisticOrder);
      }
      await orderLocalDataSource.updateCachedOrder(optimisticOrder);
      // Si el item es offline-only, no hay un "addItem" sincronizado
      // todavía al que mandarle un PATCH de cantidad — la cantidad
      // nueva va directo en el body de esa misma mutación encolada.
      final patchedQueuedAdd = item.id.startsWith('local_')
          ? await _patchQueuedAddItemQty(item.id, newQty)
          : false;
      if (!patchedQueuedAdd && !item.id.startsWith('local_')) {
        await enqueueGenericMutation(
          offlineQueue,
          method: 'PATCH',
          path: '/orders/$orderId/items/${item.id}/quantity',
          body: {'quantity': newQty},
        );
      }
      _showQueuedSnackbar();
      return true;
    }

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

  /// Busca la mutación `addItem` todavía encolada para un item
  /// offline-only (`clientRef == item.id`) y le reescribe la
  /// `quantity` en su body — para no tener que mandar un segundo PATCH
  /// de cantidad sobre un item que el servidor nunca llegó a crear.
  /// Devuelve `true` si encontró y parchó la entrada.
  Future<bool> _patchQueuedAddItemQty(String localItemId, int newQty) async {
    final match = offlineQueue.getAll().where(
      (e) =>
          e.type == QueueOperationType.genericMutation &&
          e.payload['client_ref'] == localItemId,
    );
    if (match.isEmpty) return false;
    for (final entry in match) {
      final body = Map<String, dynamic>.from(entry.payload['body'] ?? {});
      body['quantity'] = newQty;
      await offlineQueue.remove(entry.id);
      await offlineQueue.enqueue(
        QueueEntry(
          id: entry.id,
          type: entry.type,
          payload: {...entry.payload, 'body': body},
          createdAt: entry.createdAt,
        ),
      );
    }
    return true;
  }

  /// Actualiza solo el nombre del cliente en la orden. No navega a la
  /// pantalla de edición completa — es una acción rápida en un dialog.
  Future<bool> updateCustomerName(String name) async {
    if (!hasOrder) return false;
    final orderId = currentOrder!.id;
    final trimmedName = name.trim().isEmpty ? null : name.trim();

    if (!await networkInfo.isConnected) {
      final base = currentOrder!;
      // No se puede usar `base.copyWith(customerName: trimmedName)` para
      // BORRAR el nombre: ese copyWith hace `customerName ?? this.customerName`,
      // así que pasarle null no limpia nada. Reconstruimos entero solo
      // para este caso.
      final optimisticOrder = Order(
        id: base.id,
        orderNumber: base.orderNumber,
        ticketNumber: base.ticketNumber,
        orderType: base.orderType,
        orderSource: base.orderSource,
        status: base.status,
        tableId: base.tableId,
        tableElementId: base.tableElementId,
        tableName: base.tableName,
        tableLabel: base.tableLabel,
        tabSessionId: base.tabSessionId,
        customerId: base.customerId,
        customerName: trimmedName,
        customerPhone: base.customerPhone,
        deliveryAddress: base.deliveryAddress,
        assignedTo: base.assignedTo,
        assignedToName: base.assignedToName,
        items: base.items,
        subtotal: base.subtotal,
        discountAmount: base.discountAmount,
        discountPercentage: base.discountPercentage,
        deliveryFee: base.deliveryFee,
        tipAmount: base.tipAmount,
        taxAmount: base.taxAmount,
        totalAmount: base.totalAmount,
        paymentMethod: base.paymentMethod,
        paymentStatus: base.paymentStatus,
        paidAmount: base.paidAmount,
        specialInstructions: base.specialInstructions,
        estimatedTime: base.estimatedTime,
        confirmedAt: base.confirmedAt,
        preparedAt: base.preparedAt,
        deliveredAt: base.deliveredAt,
        completedAt: base.completedAt,
        cancelledAt: base.cancelledAt,
        metadata: base.metadata,
        createdAt: base.createdAt,
        updatedAt: DateTime.now(),
      );
      order.value = optimisticOrder;
      order.refresh();
      if (Get.isRegistered<OrdersController>()) {
        Get.find<OrdersController>().applyOrderUpdate(optimisticOrder);
      }
      await orderLocalDataSource.updateCachedOrder(optimisticOrder);
      await enqueueGenericMutation(
        offlineQueue,
        method: 'PATCH',
        path: ApiConstants.orderById(orderId),
        body: {'customer_name': trimmedName},
      );
      _showQueuedSnackbar();
      return true;
    }

    try {
      final usecase = sl<UpdateOrderUseCase>();
      final result = await usecase(id: orderId, customerName: trimmedName);
      return result.fold(
        (failure) {
          AppSnackbar.show('Error', failure.message);
          return false;
        },
        (updated) {
          order.value = updated;
          order.refresh();
          if (Get.isRegistered<OrdersController>()) {
            Get.find<OrdersController>().applyOrderUpdate(updated);
          }
          return true;
        },
      );
    } catch (e) {
      AppSnackbar.show('Error', e.toString());
      return false;
    }
  }

  @override
  void onClose() {
    order.value = null;
    super.onClose();
  }
}
