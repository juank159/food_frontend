import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
/// Dialog principal para procesar pagos de una orden.
///
/// Cuando ya hay pagos parciales registrados, el cobro restante NO es
/// el `orderTotal` sino lo que falta (`amountDue = total - paidAmount`).
/// El backend siempre cobra el saldo automáticamente, pero la UI tiene
/// que reflejar ESE saldo — sino el cajero pide más plata de la cuenta,
/// el cash dialog calcula mal el cambio, y el resumen se ve incorrecto.
class ProcessPaymentDialog extends StatelessWidget {
  final String orderId;
  /// Total bruto de la orden (referencia para la UI).
  final double orderTotal;
  /// Monto realmente a cobrar — el saldo pendiente. Si la orden no
  /// tiene pagos previos, coincide con `orderTotal`. Si se omite, se
  /// asume que no hay pagos previos (legacy callers).
  final double? amountDue;
  final PaymentController controller;

  const ProcessPaymentDialog({
    super.key,
    required this.orderId,
    required this.orderTotal,
    this.amountDue,
    required this.controller,
  });

  /// Lo que efectivamente se va a cobrar en este dialog.
  double get _effectiveAmount => amountDue ?? orderTotal;

  /// `true` si la orden tiene pagos previos (mostramos doble badge:
  /// total + saldo).
  bool get _hasPartialPayment =>
      amountDue != null && amountDue! < orderTotal - 0.01;

  /// Total ya cobrado en payments previos.
  double get _alreadyPaid =>
      _hasPartialPayment ? (orderTotal - amountDue!) : 0;

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
                          _hasPartialPayment
                              ? 'Cobrar saldo pendiente'
                              : 'Procesar Pago',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          // El monto destacado es el que efectivamente
                          // se va a cobrar. Si hay pagos previos, esto
                          // es el SALDO, no el total. Antes mostraba
                          // siempre `orderTotal` y el cajero pedía
                          // plata de más en la 2da pasada.
                          'A cobrar: ${CurrencyFormatter.format(_effectiveAmount)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        if (_hasPartialPayment) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Total ${CurrencyFormatter.format(orderTotal)} · '
                            'ya abonado ${CurrencyFormatter.format(_alreadyPaid)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.75),
                            ),
                          ),
                        ],
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
                    // Lista colapsada de pagos previos — sólo cuando
                    // hay pagos parciales. Antes el cajero tenía que
                    // cerrar el dialog para ver qué se había cobrado.
                    if (_hasPartialPayment) ...[
                      _PreviousPaymentsTile(
                        controller: controller,
                        orderId: orderId,
                      ),
                      const SizedBox(height: 16),
                    ],

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
            _hasPartialPayment
                ? 'Se cobrará el saldo pendiente de '
                    '${CurrencyFormatter.format(_effectiveAmount)}.'
                : 'El pago se procesará por el monto completo de '
                    '${CurrencyFormatter.format(_effectiveAmount)}.',
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
          // Pasamos el SALDO PENDIENTE (no el total), así el cálculo
          // de cambio y la validación de "recibido >= a cobrar" usan
          // el monto correcto.
          totalAmount: _effectiveAmount,
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
    // El backend siempre cobra el saldo pendiente automáticamente —
    // este `orderTotal` parámetro es informativo (no se manda en el
    // payload). Pasamos `_effectiveAmount` para que cualquier check
    // local del controller compare contra el saldo correcto.
    final payment = await controller.processOrderPayment(
      orderId: orderId,
      orderTotal: _effectiveAmount,
    );

    // Si el pago fue OK y el dialog sigue montado, cerrar devolviendo
    // el payment como resultado. El caller (`order_detail_page
    // ._showPaymentDialog`) lo usa para refrescar la lista de pagos.
    if (payment != null && context.mounted) {
      // Pulso háptico medio — confirma físicamente al operario que el
      // cobro se procesó. En POS de bar/restaurante el aviso visual
      // del snackbar puede pasar inadvertido por el ruido del local.
      HapticFeedback.mediumImpact();
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

    // Cuando el split se cierra (registró un abono parcial o el cobro
    // total), cerramos también el chooser y volvemos al detalle de la
    // orden. El detalle ya se refresca solo vía `_notifyOrderChanged`
    // del PaymentController, así que el botón "Procesar pago" mostrará
    // el saldo restante actualizado. Antes, tras un abono parcial, el
    // cajero quedaba atrapado en este dialog sin forma clara de salir.
    if (outerContext.mounted) {
      Navigator.pop(outerContext, result);
    }
  }
}

// ─────────────────────── Previous payments tile ───────────────────────

/// Tile colapsado con la lista de pagos ya cobrados de esta orden.
/// Sólo se muestra cuando hay pagos parciales (decisión del parent).
/// Carga los payments del backend al montar — el cajero ve método +
/// monto + hora de cada cobro previo sin cerrar el dialog.
class _PreviousPaymentsTile extends StatefulWidget {
  final PaymentController controller;
  final String orderId;

  const _PreviousPaymentsTile({
    required this.controller,
    required this.orderId,
  });

  @override
  State<_PreviousPaymentsTile> createState() => _PreviousPaymentsTileState();
}

class _PreviousPaymentsTileState extends State<_PreviousPaymentsTile> {
  @override
  void initState() {
    super.initState();
    // Cargamos los payments de esta orden al abrir el dialog si la
    // lista actual está vacía o pertenece a otra orden. Se hace en
    // post-frame para no llamar setState durante build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final needsReload = widget.controller.payments.isEmpty ||
          widget.controller.payments.first.orderId != widget.orderId;
      if (needsReload) {
        widget.controller.loadPaymentsByOrder(widget.orderId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final completed = widget.controller.payments
          .where((p) =>
              p.orderId == widget.orderId &&
              p.status == PaymentStatus.completed)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (completed.isEmpty) return const SizedBox.shrink();

      final total = completed.fold<double>(0, (s, p) => s + p.amount);

      return Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 4,
          ),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.history,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ),
          title: Text(
            'Ya cobrado',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            '${completed.length} '
            '${completed.length == 1 ? "pago" : "pagos"} · '
            '${CurrencyFormatter.format(total)}',
            style: theme.textTheme.bodySmall,
          ),
          children: [
            const Divider(height: 1),
            for (final p in completed)
              _PreviousPaymentRow(payment: p),
          ],
        ),
      );
    });
  }
}

class _PreviousPaymentRow extends StatelessWidget {
  final Payment payment;
  const _PreviousPaymentRow({required this.payment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = TimeOfDay.fromDateTime(payment.createdAt);
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(
            _iconFor(payment.paymentMethod),
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.paymentMethod.displayName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$hh:$mm',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.format(payment.amount),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cash:
        return Icons.payments_outlined;
      case PaymentMethod.card:
        return Icons.credit_card;
      case PaymentMethod.transfer:
        return Icons.account_balance;
      case PaymentMethod.digitalWallet:
        return Icons.account_balance_wallet_outlined;
    }
  }
}
