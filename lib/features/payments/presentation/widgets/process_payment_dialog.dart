import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/input_formatters.dart';
import '../controllers/payment_controller.dart';
import '../controllers/nequi_payment_controller.dart';
import '../controllers/breb_payment_controller.dart';
import '../../../cash_sessions/presentation/widgets/cash_session_required_banner.dart';
import '../../../orders/domain/entities/order.dart';
import '../../domain/entities/payment.dart';
import 'item_selection_sheet.dart';
import 'nequi_payment_dialog.dart';
import 'breb_payment_dialog.dart';
import 'payment_method_selector.dart';
import 'split_payment_dialog.dart';
import 'tenant_payment_account_selector.dart';

/// Dialog principal para procesar pagos de una orden.
/// Compacto y con calculadora de efectivo inline (sin segundo dialog).
class ProcessPaymentDialog extends StatefulWidget {
  final String orderId;
  final double orderTotal;
  final double? amountDue;
  final PaymentController controller;
  final Order? order;

  const ProcessPaymentDialog({
    super.key,
    required this.orderId,
    required this.orderTotal,
    this.amountDue,
    required this.controller,
    this.order,
  });

  @override
  State<ProcessPaymentDialog> createState() => _ProcessPaymentDialogState();
}

class _ProcessPaymentDialogState extends State<ProcessPaymentDialog> {
  final _cashCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  double _received = 0;

  double get _effectiveAmount => widget.amountDue ?? widget.orderTotal;
  bool get _hasPartial =>
      widget.amountDue != null && widget.amountDue! < widget.orderTotal - 0.01;
  double get _alreadyPaid => _hasPartial ? (widget.orderTotal - widget.amountDue!) : 0;
  double get _change => _received - _effectiveAmount;
  bool get _cashReady => _received >= _effectiveAmount;

  @override
  void initState() {
    super.initState();
    _cashCtrl.addListener(_onCashChanged);
  }

  @override
  void dispose() {
    _cashCtrl.removeListener(_onCashChanged);
    _cashCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onCashChanged() {
    final v = (NumberFormatHelper.parseFormattedInt(_cashCtrl.text) ?? 0).toDouble();
    setState(() => _received = v);
  }

  void _setExact() {
    _cashCtrl.text = NumberFormatHelper.formatNumber(_effectiveAmount.toInt());
  }

  Future<void> _processPayment(BuildContext context) async {
    final method = widget.controller.selectedPaymentMethod.value;

    // Sincronizar campos locales al controlador antes de procesar
    widget.controller.transactionReference.value = _referenceCtrl.text.trim();
    widget.controller.notes.value = _notesCtrl.text.trim();

    if (method == PaymentMethod.nequi) {
      await _processNequiPayment(context);
      return;
    }

    if (method == PaymentMethod.brebB) {
      await _processBrebPayment(context);
      return;
    }

    if (method == PaymentMethod.cash) {
      // Recibido es opcional; solo bloquear si ingresó un monto insuficiente
      if (_received > 0 && _received < _effectiveAmount) {
        AppSnackbar.show('Monto insuficiente',
            'El recibido debe ser al menos ${CurrencyFormatter.format(_effectiveAmount)}');
        return;
      }
      if (_received > 0) {
        widget.controller.receivedAmount.value = _received;
      }
    }
    await _executePayment(context);
  }

  Future<void> _processNequiPayment(BuildContext context) async {
    final outerContext = context;
    final nequiCtrl = NequiPaymentController(dio: GetIt.instance<Dio>());
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NequiPaymentDialog(
        controller: nequiCtrl,
        orderId: widget.orderId,
        amount: _effectiveAmount,
      ),
    );
    nequiCtrl.cancel();
    if ((confirmed ?? false) && outerContext.mounted) {
      HapticFeedback.mediumImpact();
      Navigator.pop(outerContext);
    }
  }

  Future<void> _processBrebPayment(BuildContext context) async {
    final outerContext = context;
    final brebCtrl = BrebPaymentController(dio: GetIt.instance<Dio>());
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BrebPaymentDialog(
        controller: brebCtrl,
        orderId: widget.orderId,
        amount: _effectiveAmount,
      ),
    );
    brebCtrl.cancel();
    if ((confirmed ?? false) && outerContext.mounted) {
      HapticFeedback.mediumImpact();
      Navigator.pop(outerContext);
    }
  }

  Future<void> _executePayment(BuildContext context) async {
    final payment = await widget.controller.processOrderPayment(
      orderId: widget.orderId,
      orderTotal: _effectiveAmount,
    );
    if (payment != null && context.mounted) {
      HapticFeedback.mediumImpact();
      Navigator.pop(context, payment);
    }
  }

  Future<void> _openItemSelection(BuildContext context) async {
    final ctrl = widget.controller;
    // Siempre recargar para tener datos frescos (no cachear el estado previo)
    await ctrl.loadPaymentsByOrder(widget.orderId);
    if (!context.mounted) return;

    // Calcular cuántos de cada ítem ya fueron cobrados en pagos anteriores
    final paidQtyById = <String, int>{};
    for (final p in ctrl.payments) {
      if (p.status != PaymentStatus.completed) continue;
      if (p.orderId != widget.orderId) continue;
      try {
        final decoded = jsonDecode(p.notes ?? '') as Map<String, dynamic>?;
        final rawItems = decoded?['__items__'] as List?;
        if (rawItems != null) {
          for (final raw in rawItems) {
            final m = raw as Map<String, dynamic>;
            final id = m['id'] as String?;
            final qty = (m['qty'] as num?)?.toInt() ?? 0;
            if (id != null) paidQtyById[id] = (paidQtyById[id] ?? 0) + qty;
          }
        }
      } catch (_) {}
    }

    final items = widget.order!.items
        .where((i) => i.unitPrice > 0)
        .map((i) => SelectableItemEntry(
              itemId: i.id,
              name: i.productName,
              unitPrice: i.unitPrice,
              totalQty: i.quantity,
              paidQty: paidQtyById[i.id] ?? 0,
            ))
        .toList();

    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemSelectionSheet(
        items: items,
        balance: _effectiveAmount,
        onPay: (req) async {
          if (req.method == PaymentMethod.cash) {
            ctrl.receivedAmount.value = req.receivedAmount ?? 0;
          }
          final payment = await ctrl.addPartialPayment(
            orderId: widget.orderId,
            paymentMethod: req.method,
            amount: req.amount,
            notes: req.notesJson,
            receivedAmount:
                req.method == PaymentMethod.cash ? req.receivedAmount : null,
            tenantPaymentAccountId: req.tenantAccountId,
          );
          return payment != null;
        },
      ),
    );
    if (paid == true && context.mounted) {
      HapticFeedback.mediumImpact();
      Navigator.pop(context);
    }
  }

  Future<void> _showSplitPaymentDialog(BuildContext context) async {
    final outerContext = context;
    final result = await showDialog<List<Payment>?>(
      context: context,
      builder: (_) => SplitPaymentDialog(
        orderId: widget.orderId,
        totalAmount: widget.orderTotal,
        controller: widget.controller,
      ),
    );
    if (outerContext.mounted) Navigator.pop(outerContext, result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final screen = mq.size;
    final kb = mq.viewInsets.bottom;
    final safeV = mq.viewPadding.top + mq.viewPadding.bottom;
    final hPad = screen.width < 600 ? 10.0 : 40.0;
    const vPad = 16.0;
    final maxW = screen.width < 600 ? screen.width * 0.94 : 480.0;
    final maxH = (screen.height - safeV - kb - 2 * vPad).clamp(0.0, 680.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.fromLTRB(hPad, vPad, hPad, vPad + kb),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(Icons.payment,
                      color: theme.colorScheme.onPrimaryContainer, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _hasPartial ? 'Cobrar saldo' : 'Procesar pago',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          _hasPartial
                              ? 'Total ${CurrencyFormatter.format(widget.orderTotal)} · abonado ${CurrencyFormatter.format(_alreadyPaid)}'
                              : 'A cobrar: ${CurrencyFormatter.format(_effectiveAmount)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

            // ── Contenido scrollable ───────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_hasPartial) ...[
                      _PreviousPaymentsTile(
                          controller: widget.controller,
                          orderId: widget.orderId),
                      const SizedBox(height: 12),
                    ],

                    const _SectionLabel('Método de pago'),
                    const SizedBox(height: 8),
                    Obx(() => PaymentMethodSelector(
                          selectedMethod:
                              widget.controller.selectedPaymentMethod.value,
                          onMethodSelected: (m) {
                            if (widget.controller.selectedPaymentMethod.value !=
                                m) {
                              widget.controller.selectedTenantAccountId.value =
                                  null;
                              // Reset cash state al cambiar de método
                              _cashCtrl.clear();
                              setState(() => _received = 0);
                            }
                            widget.controller.selectedPaymentMethod.value = m;
                          },
                          enabled: !widget.controller.isProcessing.value,
                        )),

                    Obx(() => TenantPaymentAccountSelector(
                          category:
                              widget.controller.selectedPaymentMethod.value,
                          controller: widget.controller,
                        )),

                    Obx(() => CashSessionRequiredBanner(
                          isCashSelected:
                              widget.controller.selectedPaymentMethod.value ==
                                  PaymentMethod.cash,
                        )),

                    const SizedBox(height: 16),
                    const _SectionLabel('Detalle del pago'),
                    const SizedBox(height: 8),

                    // Sección específica por método
                    Obx(() => _buildMethodSection(context, theme)),
                  ],
                ),
              ),
            ),

            // ── Footer ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cambio inline cuando es efectivo
                  Obx(() {
                    if (widget.controller.selectedPaymentMethod.value !=
                        PaymentMethod.cash) { return const SizedBox.shrink(); }
                    if (_received <= 0) { return const SizedBox.shrink(); }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.currency_exchange, size: 16),
                          const SizedBox(width: 6),
                          Text('Cambio: ',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          Expanded(
                            child: Text(
                              _change >= 0
                                  ? CurrencyFormatter.format(_change)
                                  : 'Falta ${CurrencyFormatter.format(-_change)}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: _change >= 0
                                    ? AppColors.success
                                    : theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // Botones secundarios
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.splitscreen, size: 16),
                          label: const Text('Dividir'),
                          onPressed: () => _showSplitPaymentDialog(context),
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8)),
                        ),
                      ),
                      if (widget.order != null &&
                          widget.order!.items.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.checklist_rtl, size: 16),
                            label: const Text('Por ítems'),
                            onPressed: () => _openItemSelection(context),
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 40),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Botón principal
                  Obx(() {
                    final isCash =
                        widget.controller.selectedPaymentMethod.value ==
                            PaymentMethod.cash;
                    final cashOk = canSubmitWithCashGuard(isCash);
                    final processing = widget.controller.isProcessing.value;
                    // Para efectivo además necesitamos que haya monto suficiente
                    final cashAmountOk = !isCash || _cashReady;
                    final disabled = processing || !cashOk;

                    return FilledButton.icon(
                      onPressed: disabled ? null : () => _processPayment(context),
                      icon: processing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Icon(!cashOk
                              ? Icons.lock_outline
                              : (isCash && !cashAmountOk)
                                  ? Icons.payments_outlined
                                  : Icons.check_circle_outline),
                      label: Text(
                        processing
                            ? 'Procesando...'
                            : !cashOk
                                ? 'Abrí caja para cobrar'
                                : 'Procesar pago',
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48)),
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

  Widget _buildMethodSection(BuildContext context, ThemeData theme) {
    switch (widget.controller.selectedPaymentMethod.value) {
      case PaymentMethod.cash:
        return _buildCashSection(theme);
      case PaymentMethod.nequi:
        return _buildNequiInfo(theme);
      case PaymentMethod.brebB:
        return _buildBrebInfo(theme);
      case PaymentMethod.card:
      case PaymentMethod.transfer:
      case PaymentMethod.digitalWallet:
        return _buildElectronicInfo(theme);
    }
  }

  Widget _buildCashSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _cashCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsSeparatorInputFormatter()],
          decoration: InputDecoration(
            labelText: 'Recibido (opcional)',
            prefixText: '\$ ',
            hintText: NumberFormatHelper.formatNumber(_effectiveAmount.toInt()),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            suffixIcon: TextButton(
              onPressed: _setExact,
              child: const Text('Exacto', style: TextStyle(fontSize: 12)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildNotesField(),
      ],
    );
  }

  Widget _buildNequiInfo(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF32AF60).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFF32AF60).withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              const Icon(Icons.qr_code_2, color: Color(0xFF32AF60), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Se generará un QR de Nequi. El cliente lo escanea con la app.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildNotesField(),
      ],
    );
  }

  Widget _buildBrebInfo(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF32AF60).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFF32AF60).withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              const Icon(Icons.bolt, color: Color(0xFF32AF60), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Le mostrás la llave Bre-B al cliente y transfiere desde su banco. Se confirma solo.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildNotesField(),
      ],
    );
  }

  Widget _buildElectronicInfo(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _referenceCtrl,
          decoration: InputDecoration(
            labelText: 'Referencia (opcional)',
            hintText: 'Voucher, ID transacción, etc.',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
          ),
        ),
        const SizedBox(height: 12),
        _buildNotesField(),
      ],
    );
  }

  Widget _buildNotesField() {
    return TextField(
      controller: _notesCtrl,
      maxLines: 2,
      decoration: InputDecoration(
        labelText: 'Notas (opcional)',
        hintText: 'Detalle interno',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
    );
  }
}

// ─────────────────────── Previous payments tile ───────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
          letterSpacing: 0.4,
        ),
      );
}

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
            paymentMethodIcon(payment.paymentMethod),
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

}

