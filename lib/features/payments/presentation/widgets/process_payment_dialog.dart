import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../controllers/payment_controller.dart';
import 'cash_payment_dialog.dart';
import 'payment_method_selector.dart';
import 'split_payment_dialog.dart';
import 'tenant_payment_account_selector.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../cash_sessions/presentation/widgets/cash_session_required_banner.dart';
import '../../domain/entities/payment.dart';

/// Process Payment Dialog
/// Dialog principal para procesar pagos de una orden
class ProcessPaymentDialog extends StatelessWidget {
  final String orderId;
  final double orderTotal;
  final PaymentController controller;

  const ProcessPaymentDialog({
    super.key,
    required this.orderId,
    required this.orderTotal,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = MediaQuery.of(context).size;
    // En mobile llenamos casi la pantalla; en tablet/desktop usamos un diálogo
    // de tamaño fijo pero razonable. `min` con `screen.width` evita overflow
    // horizontal en pantallas más angostas que 500px (iPhone SE, etc).
    final maxW = screen.width < 600
        ? screen.width * 0.92
        : (screen.width < 900 ? 480.0 : 500.0);
    final maxH = screen.height < 700
        ? screen.height * 0.9
        : 700.0;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: screen.width < 600 ? 16 : 40,
        vertical: screen.height < 700 ? 16 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.secondaryContainer,
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.payment,
                      color: theme.colorScheme.onPrimary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Procesar Pago',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total: ${CurrencyFormatter.format(orderTotal)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Payment Method Selector
                    Obx(() => PaymentMethodSelector(
                          selectedMethod: controller.selectedPaymentMethod.value,
                          onMethodSelected: (method) {
                            // Resetear la cuenta específica cuando cambia
                            // la categoría — la cuenta anterior puede no
                            // pertenecer a la categoría nueva.
                            if (controller.selectedPaymentMethod.value !=
                                method) {
                              controller.selectedTenantAccountId.value = null;
                            }
                            controller.selectedPaymentMethod.value = method;
                          },
                          enabled: !controller.isProcessing.value,
                        )),

                    // Selector de cuenta específica del tenant
                    // (Nequi, Bancolombia, etc.). Se autocolapsa si el
                    // tenant no tiene cuentas para la categoría elegida.
                    Obx(() => TenantPaymentAccountSelector(
                          category: controller.selectedPaymentMethod.value,
                          controller: controller,
                        )),

                    // Banner inline: solo aparece cuando el método
                    // seleccionado es CASH y el cajero NO tiene caja
                    // abierta. Ofrece abrir caja sin perder este cobro.
                    // El backend rechaza igual el submit si no hay
                    // sesión, pero advertimos antes para mejor UX.
                    Obx(() => CashSessionRequiredBanner(
                          isCashSelected: controller
                                  .selectedPaymentMethod.value ==
                              PaymentMethod.cash,
                        )),

                    const SizedBox(height: 24),

                    // Additional Info based on method
                    Obx(() => _buildMethodSpecificInfo(context, theme)),
                  ],
                ),
              ),
            ),

            // Footer with Actions
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Split Payment Option
                  OutlinedButton.icon(
                    icon: const Icon(Icons.splitscreen),
                    label: const Text('Dividir Pago'),
                    onPressed: () => _showSplitPaymentDialog(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Process Payment Button.
                  // Doble validación reactiva:
                  //   1. `isProcessing` → evita doble submit.
                  //   2. `canSubmitWithCashGuard` → si el método es cash
                  //      y el cajero no tiene caja abierta, deshabilitamos
                  //      el botón. El banner inline ya le ofrece "Abrir
                  //      caja ahora" — esto cierra el último gap.
                  Obx(() {
                    final isCash = controller.selectedPaymentMethod.value ==
                        PaymentMethod.cash;
                    final cashOk = canSubmitWithCashGuard(isCash);
                    final processing = controller.isProcessing.value;
                    final disabled = processing || !cashOk;

                    return FilledButton.icon(
                      onPressed: disabled ? null : () => _processPayment(context),
                      icon: processing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(!cashOk ? Icons.lock_outline : Icons.check_circle),
                      label: Text(
                        processing
                            ? 'Procesando...'
                            : (!cashOk
                                ? 'Abrí caja para cobrar en efectivo'
                                : 'Procesar Pago'),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodSpecificInfo(BuildContext context, ThemeData theme) {
    final method = controller.selectedPaymentMethod.value;

    switch (method) {
      case PaymentMethod.cash:
        return _buildCashInfo(context, theme);
      case PaymentMethod.card:
      case PaymentMethod.transfer:
      case PaymentMethod.digitalWallet:
        return _buildElectronicPaymentInfo(context, theme);
    }
  }

  Widget _buildCashInfo(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Se abrirá una calculadora para ingresar el monto recibido y calcular el cambio automáticamente.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElectronicPaymentInfo(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pago electrónico por el monto total',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'El pago se procesará por el monto completo de ${CurrencyFormatter.format(orderTotal)}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Future<void> _processPayment(BuildContext context) async {
    final method = controller.selectedPaymentMethod.value;

    if (method == PaymentMethod.cash) {
      // OJO: capturamos `outerContext` (el del ProcessPaymentDialog)
      // ANTES de abrir el cash dialog. Cuando el cash dialog se
      // cierra y dispara `onConfirm`, el context del builder del
      // cash dialog YA está muerto — pero `outerContext` sigue vivo
      // porque el ProcessPaymentDialog aún no se cerró. Usamos
      // `outerContext` para el pop final del ProcessPaymentDialog.
      final outerContext = context;
      await showDialog(
        context: context,
        builder: (cashContext) => CashPaymentDialog(
          totalAmount: orderTotal,
          onConfirm: (receivedAmount) async {
            controller.receivedAmount.value = receivedAmount;
            await _executePayment(outerContext);
          },
        ),
      );
    } else {
      // Electrónico: procesar directo sin paso intermedio.
      await _executePayment(context);
    }
  }

  Future<void> _executePayment(BuildContext context) async {
    final payment = await controller.processOrderPayment(
      orderId: orderId,
      orderTotal: orderTotal,
    );

    // Si el pago fue OK y el dialog sigue montado, cerrar devolviendo
    // el payment como resultado. El caller (`order_detail_page
    // ._showPaymentDialog`) lo usa para refrescar la lista de pagos.
    if (payment != null && context.mounted) {
      Navigator.pop(context, payment);
    }
  }

  Future<void> _showSplitPaymentDialog(BuildContext context) async {
    // El nuevo SplitPaymentDialog persiste cada pago al instante
    // (`addPartialPayment`). Cuando se cierra, devuelve la lista de
    // payments reales del backend. Si la orden quedó completamente
    // pagada, cerramos también el ProcessPaymentDialog devolviendo
    // esos payments al caller (order detail page) para refresh.
    final outerContext = context;
    final result = await showDialog<List<Payment>?>(
      context: context,
      builder: (_) => SplitPaymentDialog(
        orderId: orderId,
        totalAmount: orderTotal,
        controller: controller,
      ),
    );

    final paidSum = (result ?? const <Payment>[])
        .where((p) => p.status == PaymentStatus.completed)
        .fold<double>(0, (sum, p) => sum + p.amount);
    final fullyPaid = paidSum >= orderTotal - 0.01;

    if (fullyPaid && outerContext.mounted) {
      Navigator.pop(outerContext, result);
    }
  }
}
