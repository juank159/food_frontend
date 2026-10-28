// lib/features/payments/presentation/controllers/payment_controller.dart
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../../../orders/data/datasources/order_local_datasource.dart';
import '../../../orders/domain/entities/order.dart' as order_entity;
import '../../../orders/presentation/controllers/order_detail_controller.dart';
import '../../../orders/presentation/controllers/orders_controller.dart';
import '../../../printer_configs/data/printing_orchestrator.dart';
import '../../../tab_sessions/presentation/controllers/tab_session_detail_controller.dart';
import '../../domain/entities/payment.dart';
import '../../domain/usecases/create_payment_usecase.dart';
import '../../domain/usecases/get_payments_by_order_usecase.dart';
import '../../domain/usecases/process_order_payment_usecase.dart';
import '../../domain/usecases/refund_payment_usecase.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../cash_sessions/presentation/widgets/cash_session_error_handler.dart';

/// Payment Controller
/// Controlador para manejar el estado y lógica de pagos
class PaymentController extends GetxController {
  final ProcessOrderPaymentUseCase processOrderPaymentUseCase;
  final GetPaymentsByOrderUseCase getPaymentsByOrderUseCase;
  final RefundPaymentUseCase refundPaymentUseCase;
  final CreatePaymentUseCase createPaymentUseCase;

  PaymentController({
    required this.processOrderPaymentUseCase,
    required this.getPaymentsByOrderUseCase,
    required this.refundPaymentUseCase,
    required this.createPaymentUseCase,
  });

  // Observable States
  final RxList<Payment> payments = <Payment>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isProcessing = false.obs;
  final RxString errorMessage = ''.obs;
  final Rx<Payment?> selectedPayment = Rx<Payment?>(null);

  // Payment Form Data
  final Rx<PaymentMethod> selectedPaymentMethod = PaymentMethod.cash.obs;
  final RxDouble receivedAmount = 0.0.obs;
  final RxString transactionReference = ''.obs;
  final RxString notes = ''.obs;

  /// Carga los pagos de una orden
  Future<void> loadPaymentsByOrder(String orderId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final result = await getPaymentsByOrderUseCase(orderId);

      result.fold(
        (failure) {
          errorMessage.value = failure.message;
          // Sin internet se conserva lo ya cargado (y los cobros offline
          // de `_applyOfflinePayment`) — no hay error que mostrar.
          if (failure is NetworkFailure) return;
          AppSnackbar.show(
            'Error',
            failure.message,
            snackPosition: SnackPosition.TOP,
          );
        },
        (paymentsList) {
          payments.value = paymentsList;
        },
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Procesa el pago completo de una orden.
  ///
  /// `allowCashSessionRetry` es interno — controla el reintento
  /// automático UNA sola vez tras abrir caja (ver el bug real
  /// documentado en `_handleCashSessionRequired`). No pasar `false`
  /// desde afuera.
  Future<Payment?> processOrderPayment({
    required String orderId,
    required double orderTotal,
    bool allowCashSessionRetry = true,
  }) async {
    try {
      isProcessing.value = true;
      errorMessage.value = '';

      final result = await processOrderPaymentUseCase(
        orderId: orderId,
        paymentMethod: selectedPaymentMethod.value,
        receivedAmount: selectedPaymentMethod.value == PaymentMethod.cash
            ? receivedAmount.value
            : null,
        transactionReference: transactionReference.value.isNotEmpty
            ? transactionReference.value
            : null,
        notes: notes.value.isNotEmpty ? notes.value : null,
      );

      Failure? foldFailure;
      Payment? createdPayment;
      result.fold((f) => foldFailure = f, (p) => createdPayment = p);

      if (foldFailure != null) {
        final failure = foldFailure!;
        errorMessage.value = failure.message;
        if (isCashSessionRequiredError(failure.message)) {
          return _handleCashSessionRequired(
            allowRetry: allowCashSessionRetry,
            message: failure.message,
            retry: () => processOrderPayment(
              orderId: orderId,
              orderTotal: orderTotal,
              allowCashSessionRetry: false,
            ),
          );
        }
        AppSnackbar.show(
          'Error',
          failure.message,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
          duration: const Duration(seconds: 5),
        );
        return null;
      }

      final payment = createdPayment!;
      AppSnackbar.show(
        'Pago exitoso',
        'Pago procesado correctamente',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.primary,
        colorText: Get.theme.colorScheme.onPrimary,
        duration: const Duration(seconds: 3),
      );

      // Agregar a la lista de pagos
      payments.add(payment);
      _notifyOrderChanged(orderId, tryPrintReceipt: true);

      // Resetear formulario
      resetPaymentForm();

      return payment;
    } finally {
      isProcessing.value = false;
    }
  }

  /// Bug real corregido: cuando el cobro fallaba por `CASH_SESSION_
  /// REQUIRED`, se llamaba `handleCashSessionError(...)` SIN `await`
  /// (fire-and-forget) y se devolvía `null` de una — el dialog de
  /// "Necesitás abrir caja" aparecía ENCIMA del dialog de cobro, pero
  /// el pago original nunca se reintentaba. El cajero terminaba
  /// abriendo caja y viendo el dialog de cobro ahí parado, sin cerrarse
  /// ni procesar nada — parecía que "no dejaba cobrar".
  ///
  /// Ahora se espera el resultado del dialog y, si el cajero abrió
  /// caja desde ahí, se reintenta el MISMO cobro automáticamente —
  /// una sola vez (`allowRetry` evita loop infinito si algo más sigue
  /// fallando después de abrir caja).
  Future<Payment?> _handleCashSessionRequired({
    required bool allowRetry,
    required String message,
    required Future<Payment?> Function() retry,
  }) async {
    final opened = await handleCashSessionError(message);
    if (opened && allowRetry) {
      return retry();
    }
    return null;
  }

  /// Registra UN pago parcial inmediato.
  ///
  /// **Diferencia con `processSplitPayments`:**
  /// - `processSplitPayments` envía N pagos en un batch atómico — si el
  ///   usuario cierra el dialog antes de "Confirmar", se pierden todos.
  /// - `addPartialPayment` envía 1 pago al toque y persiste. Si el
  ///   operario sale del flujo, el dinero recibido YA quedó en caja.
  ///
  /// Refresca la lista local de payments al éxito para que la UI vea
  /// el nuevo balance al instante. Si el método es cash y no hay caja
  /// abierta, el backend rechaza con `CASH_SESSION_REQUIRED` y nosotros
  /// abrimos el dialog amigable de "Abrí caja" (mismo flujo que el
  /// cobro full).
  Future<Payment?> addPartialPayment({
    required String orderId,
    required PaymentMethod paymentMethod,
    required double amount,
    double? receivedAmount,
    String? transactionReference,
    String? notes,
    bool allowCashSessionRetry = true,
  }) async {
    try {
      isProcessing.value = true;
      errorMessage.value = '';

      final result = await createPaymentUseCase(
        orderId: orderId,
        paymentMethod: paymentMethod,
        amount: amount,
        receivedAmount: receivedAmount,
        transactionReference: transactionReference,
        notes: notes,
      );

      Failure? foldFailure;
      Payment? createdPayment;
      result.fold((f) => foldFailure = f, (p) => createdPayment = p);

      if (foldFailure is OfflineQueuedFailure) {
        return _applyOfflinePayment(
          orderId: orderId,
          paymentMethod: paymentMethod,
          amount: amount,
          receivedAmount: receivedAmount,
          transactionReference: transactionReference,
          notes: notes,
        );
      }

      if (foldFailure != null) {
        final failure = foldFailure!;
        errorMessage.value = failure.message;
        if (isCashSessionRequiredError(failure.message)) {
          return _handleCashSessionRequired(
            allowRetry: allowCashSessionRetry,
            message: failure.message,
            retry: () => addPartialPayment(
              orderId: orderId,
              paymentMethod: paymentMethod,
              amount: amount,
              receivedAmount: receivedAmount,
              transactionReference: transactionReference,
              notes: notes,
              allowCashSessionRetry: false,
            ),
          );
        }
        AppSnackbar.show(
          'No se pudo registrar el pago',
          failure.message,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
        );
        return null;
      }

      final payment = createdPayment!;
      payments.add(payment);
      // Propagar el cambio al detalle de la orden y, en cascada,
      // a la lista de órdenes — así la card se actualiza sin
      // pull-to-refresh manual al volver al listado.
      _notifyOrderChanged(orderId, tryPrintReceipt: true);
      AppSnackbar.show(
        'Pago registrado',
        '${paymentMethod.displayName} · ${payment.amount.toStringAsFixed(0)}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.primary,
        colorText: Get.theme.colorScheme.onPrimary,
        duration: const Duration(seconds: 2),
      );
      return payment;
    } finally {
      isProcessing.value = false;
    }
  }

  /// Reembolsa un pago
  Future<Payment?> refundPayment({
    required String paymentId,
    double? refundAmount,
    required String refundReason,
  }) async {
    try {
      isProcessing.value = true;
      errorMessage.value = '';

      final result = await refundPaymentUseCase(
        paymentId: paymentId,
        refundAmount: refundAmount,
        refundReason: refundReason,
      );

      return result.fold(
        (failure) {
          errorMessage.value = failure.message;
          AppSnackbar.show(
            'Error',
            failure.message,
            snackPosition: SnackPosition.TOP,
            backgroundColor: Get.theme.colorScheme.error,
            colorText: Get.theme.colorScheme.onError,
            duration: const Duration(seconds: 5),
          );
          return null;
        },
        (payment) {
          AppSnackbar.show(
            'Reembolso exitoso',
            'Pago reembolsado correctamente',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Get.theme.colorScheme.primary,
            colorText: Get.theme.colorScheme.onPrimary,
            duration: const Duration(seconds: 3),
          );

          // Actualizar en la lista
          final index = payments.indexWhere((p) => p.id == paymentId);
          if (index != -1) {
            payments[index] = payment;
          }
          // Refund cambia paid_amount y posiblemente payment_status.
          // Notificar al detalle si está mostrando esta orden.
          _notifyOrderChanged(payment.orderId);

          return payment;
        },
      );
    } finally {
      isProcessing.value = false;
    }
  }

  /// Refresca una orden después de un pago que el backend registró por
  /// Pago cobrado SIN internet: ya quedó en la cola y se manda solo al
  /// volver la señal (`SyncHandlers` → `POST /payments`). Bug real
  /// reportado: antes esto fallaba con "Sin conexión" y el ticket
  /// seguía debiendo. Ahora se refleja al instante en el detalle, las
  /// listas y la caché de órdenes, igual que si el servidor hubiera
  /// respondido — sin pedirle nada a la red.
  Payment _applyOfflinePayment({
    required String orderId,
    required PaymentMethod paymentMethod,
    required double amount,
    double? receivedAmount,
    String? transactionReference,
    String? notes,
  }) {
    final now = DateTime.now();
    final payment = Payment(
      id: 'local_pending_${now.microsecondsSinceEpoch}',
      orderId: orderId,
      paymentMethod: paymentMethod,
      amount: amount,
      receivedAmount: receivedAmount,
      changeAmount: receivedAmount != null && receivedAmount > amount
          ? receivedAmount - amount
          : null,
      transactionReference: transactionReference,
      status: PaymentStatus.completed,
      processedBy: '',
      processedAt: now,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
    payments.add(payment);

    final base = _findOrderInMemory(orderId);
    if (base != null) {
      final paid = base.paidAmount + amount;
      final itemQty = Map<String, int>.from(base.paidItemQuantities);
      try {
        final decoded = jsonDecode(notes ?? '') as Map<String, dynamic>?;
        for (final raw in (decoded?['__items__'] as List?) ?? const []) {
          final m = raw as Map<String, dynamic>;
          final id = m['id'] as String?;
          final qty = (m['qty'] as num?)?.toInt() ?? 0;
          if (id != null) itemQty[id] = (itemQty[id] ?? 0) + qty;
        }
      } catch (_) {}
      final updated = base.copyWith(
        paidAmount: paid,
        paidItemQuantities: itemQty,
        paymentMethod: paymentMethod,
        paymentStatus: paid >= base.totalAmount - 0.01
            ? PaymentStatus.completed
            : base.paymentStatus,
      );
      if (Get.isRegistered<OrdersController>()) {
        Get.find<OrdersController>().applyOrderUpdate(updated);
      } else if (Get.isRegistered<OrderDetailController>()) {
        Get.find<OrderDetailController>().acceptExternalUpdate(updated);
      }
      sl<OrderLocalDataSource>().updateCachedOrder(updated).ignore();
    }

    AppSnackbar.show(
      'Pago guardado sin internet',
      '${paymentMethod.displayName} · ${amount.toStringAsFixed(0)} — se envía solo al volver la señal',
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 3),
    );
    return payment;
  }

  order_entity.Order? _findOrderInMemory(String orderId) {
    if (Get.isRegistered<OrderDetailController>()) {
      final current = Get.find<OrderDetailController>().currentOrder;
      if (current?.id == orderId) return current;
    }
    if (Get.isRegistered<OrdersController>()) {
      final c = Get.find<OrdersController>();
      for (final list in [c.orders, c.activeOrders, c.unpaidOrders]) {
        for (final o in list) {
          if (o.id == orderId) return o;
        }
      }
    }
    return null;
  }

  /// fuera del flujo sincrónico normal — hoy solo Bre-B, que se confirma
  /// recién cuando el backend concilia el correo del banco (llega por
  /// push/polling, no como respuesta directa de un POST /payments). Como
  /// ese flujo nunca pasa por `processOrderPayment`/`addPartialPayment`,
  /// tampoco disparaba `_notifyOrderChanged` ni recargaba el historial:
  /// el cajero veía el diálogo cerrarse pero el detalle de la orden
  /// (saldo, estado, historial de pagos) se quedaba con datos viejos
  /// hasta un refresh manual.
  Future<void> refreshAfterExternalPayment(String orderId) async {
    await loadPaymentsByOrder(orderId);
    _notifyOrderChanged(orderId, tryPrintReceipt: true);
  }

  /// Propaga el cambio tras un cobro a TODOS los lugares que tienen
  /// la orden en memoria — lista global, lista de activas, detalle si
  /// está abierto. Lo centralizamos vía `OrdersController.reloadAndApply`
  /// que hace un único GET y aplica el resultado en cascada.
  ///
  /// Antes este flujo dependía del `OrderDetailController.refresh()`,
  /// que NO actualizaba la lista si el detalle se cerraba antes de que
  /// el GET terminara, o si el cobro ocurría desde una pantalla donde
  /// el detalle ni estaba registrado. Resultado: el usuario veía data
  /// vieja en el listado y tenía que pull-to-refresh.
  ///
  /// **Auto-print del recibo:** si la orden quedó totalmente pagada y
  /// no la imprimimos antes en esta sesión, disparamos
  /// `PrintingOrchestrator.autoPrintReceipt` fire-and-forget. El set
  /// `_printedReceiptIds` evita re-imprimir si hay varios cobros
  /// parciales que terminan completando.
  void _notifyOrderChanged(String orderId, {bool tryPrintReceipt = false}) {
    if (Get.isRegistered<OrdersController>()) {
      final orders = Get.find<OrdersController>();
      orders.reloadAndApply(orderId).then((updated) async {
        if (updated == null) return;
        if (!tryPrintReceipt) return;
        if (!updated.isPaymentCompleted) return;
        if (_printedReceiptIds.contains(updated.id)) return;
        _printedReceiptIds.add(updated.id);
        await PrintingOrchestrator.autoPrintReceipt(
          orderId: updated.id,
          subtitle: updated.displayTableLabel,
        );
      });
    } else {
      // OrdersController no está montado (ej. se entró al detalle desde
      // una cuenta abierta): antes el detalle quedaba con el saldo viejo.
      if (Get.isRegistered<OrderDetailController>()) {
        final detail = Get.find<OrderDetailController>();
        if (detail.currentOrder?.id == orderId) detail.refresh();
      }
      // Fetch propio para verificar si quedó pagada e imprimir.
      if (tryPrintReceipt) _fetchAndTryPrint(orderId);
    }
    // Si el ticket es de una cuenta abierta y su detalle está en pantalla,
    // también se refresca (saldo de la cuenta, ticket "Pagado").
    if (Get.isRegistered<TabSessionDetailController>()) {
      Get.find<TabSessionDetailController>().load();
    }
  }

  Future<void> _fetchAndTryPrint(String orderId) async {
    if (_printedReceiptIds.contains(orderId)) return;
    try {
      final dio = sl<Dio>();
      final res = await dio.get('/orders/$orderId');
      final data = ApiResponseUtils.object(res);
      if ((data['payment_status'] as String?) != 'paid') return;
      _printedReceiptIds.add(orderId);
      final tableLabel = (data['table_label'] as String?)?.isNotEmpty == true
          ? data['table_label'] as String
          : (data['table_name'] as String?);
      await PrintingOrchestrator.autoPrintReceipt(
        orderId: orderId,
        subtitle: tableLabel,
      );
    } catch (_) {}
  }

  /// IDs de órdenes para las cuales ya disparamos auto-print del
  /// recibo en esta sesión. Evita re-imprimir si llegan varios
  /// `_notifyOrderChanged` después del cobro final.
  final Set<String> _printedReceiptIds = <String>{};

  /// Calcula el total pagado de una orden
  double getTotalPaid() {
    return payments
        .where((p) => p.status == PaymentStatus.completed)
        .fold(0.0, (sum, p) => sum + p.amount);
  }

  /// Calcula el cambio para pago en efectivo
  double calculateChange(double orderTotal) {
    if (selectedPaymentMethod.value != PaymentMethod.cash) return 0.0;
    if (receivedAmount.value <= 0) return 0.0;
    final change = receivedAmount.value - orderTotal;
    return change > 0 ? change : 0.0;
  }

  /// Valida si se puede procesar el pago
  bool canProcessPayment(double orderTotal) {
    if (selectedPaymentMethod.value == PaymentMethod.cash) {
      return receivedAmount.value >= orderTotal;
    }
    return true; // Para otros métodos, no se requiere validación del monto
  }

  /// Resetea el formulario de pago
  void resetPaymentForm() {
    selectedPaymentMethod.value = PaymentMethod.cash;
    receivedAmount.value = 0.0;
    transactionReference.value = '';
    notes.value = '';
  }

  /// Selecciona un pago
  void selectPayment(Payment payment) {
    selectedPayment.value = payment;
  }

  /// Limpia el pago seleccionado
  void clearSelectedPayment() {
    selectedPayment.value = null;
  }
}

