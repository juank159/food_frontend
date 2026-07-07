// lib/features/payments/presentation/controllers/payment_controller.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../../../orders/presentation/controllers/orders_controller.dart';
import '../../../printer_configs/data/printing_orchestrator.dart';
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
  // ID de la cuenta de pago específica del tenant (Nequi #1, Bancolombia
  // Ahorros, etc.). Opcional — si el tenant no tiene cuentas configuradas,
  // queda null y el backend acepta el pago solo con la categoría.
  final RxnString selectedTenantAccountId = RxnString();

  /// Carga los pagos de una orden
  Future<void> loadPaymentsByOrder(String orderId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final result = await getPaymentsByOrderUseCase(orderId);

      result.fold(
        (failure) {
          errorMessage.value = failure.message;
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

  /// Procesa el pago completo de una orden
  Future<Payment?> processOrderPayment({
    required String orderId,
    required double orderTotal,
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
        tenantPaymentAccountId: selectedTenantAccountId.value,
      );

      return result.fold(
        (failure) {
          errorMessage.value = failure.message;
          // Si es el código semántico de "falta caja", mostramos el
          // dialog amigable en lugar del snackbar genérico. El cajero
          // puede abrir caja sin perder el flujo.
          if (isCashSessionRequiredError(failure.message)) {
            handleCashSessionError(failure.message);
            return null;
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
        },
        (payment) {
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
        },
      );
    } finally {
      isProcessing.value = false;
    }
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
    String? tenantPaymentAccountId,
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
        tenantPaymentAccountId: tenantPaymentAccountId,
      );

      return result.fold(
        (failure) {
          errorMessage.value = failure.message;
          if (isCashSessionRequiredError(failure.message)) {
            handleCashSessionError(failure.message);
            return null;
          }
          AppSnackbar.show(
            'No se pudo registrar el pago',
            failure.message,
            snackPosition: SnackPosition.TOP,
            backgroundColor: Get.theme.colorScheme.error,
            colorText: Get.theme.colorScheme.onError,
          );
          return null;
        },
        (payment) {
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
        },
      );
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
    } else if (tryPrintReceipt) {
      // OrdersController no está montado (ej. usuario entró directo al
      // detalle). Hacemos fetch propio para verificar si quedó pagada.
      _fetchAndTryPrint(orderId);
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
    selectedTenantAccountId.value = null;
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

