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
import '../../../cash_sessions/presentation/widgets/cash_session_required_banner.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/domain/entities/order_item.dart';
import '../../domain/entities/payment.dart';
import 'nequi_payment_dialog.dart';
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

    if (method == PaymentMethod.cash) {
      if (!_cashReady) {
        AppSnackbar.show('Monto insuficiente',
            'El monto recibido debe ser al menos ${CurrencyFormatter.format(_effectiveAmount)}');
        return;
      }
      widget.controller.receivedAmount.value = _received;
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
    final payment = await showModalBottomSheet<Payment>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderItemSelectionSheet(
        items: widget.order!.items,
        maxAmount: _effectiveAmount,
        orderId: widget.orderId,
        controller: widget.controller,
      ),
    );
    if (payment != null && context.mounted) {
      HapticFeedback.mediumImpact();
      Navigator.pop(context, payment);
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
    final safeV = mq.viewPadding.top + mq.viewPadding.bottom;
    final maxW = screen.width < 600 ? screen.width * 0.94 : 480.0;
    final maxH = (screen.height - safeV - 32).clamp(0.0, 680.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: screen.width < 600 ? 10 : 40,
        vertical: mq.viewPadding.bottom + 16,
      ),
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

// ────────────────── Selección de ítems + pago directo ──────────────────

class _OrderSelectableItem {
  final OrderItem item;
  int selectedQty;

  _OrderSelectableItem({required this.item}) : selectedQty = item.quantity;

  bool get isSelected => selectedQty > 0;
  double get subtotal => item.unitPrice * selectedQty;
}

/// Sheet que combina selección de ítems + método de pago + procesamiento
/// en un solo paso. No devuelve un monto — devuelve el `Payment` ya
/// registrado para que el caller cierre el dialog padre directamente.
class _OrderItemSelectionSheet extends StatefulWidget {
  final List<OrderItem> items;
  final double maxAmount;
  final String orderId;
  final PaymentController controller;

  const _OrderItemSelectionSheet({
    required this.items,
    required this.maxAmount,
    required this.orderId,
    required this.controller,
  });

  @override
  State<_OrderItemSelectionSheet> createState() =>
      _OrderItemSelectionSheetState();
}

class _OrderItemSelectionSheetState extends State<_OrderItemSelectionSheet> {
  late final List<_OrderSelectableItem> _selectables;
  bool _processing = false;
  // Campo "recibido" inline para efectivo
  final _cashCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectables = widget.items
        .where((i) => i.unitPrice > 0)
        .map((i) => _OrderSelectableItem(item: i))
        .toList();
  }

  @override
  void dispose() {
    _cashCtrl.dispose();
    super.dispose();
  }

  double get _total => _selectables.fold(0, (s, i) => s + i.subtotal);

  bool get _isCash =>
      widget.controller.selectedPaymentMethod.value == PaymentMethod.cash;

  double get _parsedReceived {
    final raw = _cashCtrl.text.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(raw) ?? 0;
  }

  Future<void> _confirm() async {
    final total = _total;
    if (total <= 0 || total > widget.maxAmount + 0.01) return;
    if (_isCash) {
      final rec = _parsedReceived;
      if (rec < total) {
        AppSnackbar.show('Monto insuficiente',
            'El recibido debe ser ≥ ${CurrencyFormatter.format(total)}');
        return;
      }
      widget.controller.receivedAmount.value = rec;
    }
    setState(() => _processing = true);
    final payment = await widget.controller.addPartialPayment(
      orderId: widget.orderId,
      paymentMethod: widget.controller.selectedPaymentMethod.value,
      amount: total,
      receivedAmount: _isCash ? widget.controller.receivedAmount.value : null,
      tenantPaymentAccountId: widget.controller.selectedTenantAccountId.value,
    );
    if (!mounted) return;
    setState(() => _processing = false);
    if (payment != null) Navigator.pop(context, payment);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    // Cuando el teclado sube, reducimos maxHeight para que el sheet
    // se achique y el footer quede visible encima del teclado.
    final kb = mq.viewInsets.bottom;
    final safeBottom = mq.viewPadding.bottom;
    final isSmall = mq.size.height < 700;
    final vPad = isSmall ? 8.0 : 12.0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: mq.size.height * 0.92 - kb,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.symmetric(vertical: isSmall ? 8 : 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 8, isSmall ? 4 : 8),
            child: Row(
              children: [
                Icon(Icons.checklist_rtl,
                    color: AppColors.primary, size: isSmall ? 20 : 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cobrar por ítems',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Lista — Expanded llena el espacio disponible y hace scroll
          // internamente. shrinkWrap:true causaba que la lista reportara
          // su alto real sin límite → la Column superaba maxHeight.
          Expanded(
            child: ListView.separated(
              itemCount: _selectables.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = _selectables[i];
                return _OrderItemTile(
                  selectable: s,
                  onIncrement: s.selectedQty < s.item.quantity
                      ? () => setState(() => s.selectedQty++)
                      : null,
                  onDecrement: s.selectedQty > 0
                      ? () => setState(() => s.selectedQty--)
                      : null,
                );
              },
            ),
          ),
          const Divider(height: 1),
          // Footer — padding compacto en pantallas pequeñas
          Padding(
            padding: EdgeInsets.fromLTRB(16, vPad, 16, vPad + safeBottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Método de pago
                Obx(() => PaymentMethodSelector(
                      selectedMethod:
                          widget.controller.selectedPaymentMethod.value,
                      onMethodSelected: (m) =>
                          widget.controller.selectedPaymentMethod.value = m,
                    )),
                // Campo recibido para efectivo
                Obx(() {
                  if (widget.controller.selectedPaymentMethod.value !=
                      PaymentMethod.cash) {
                    return const SizedBox.shrink();
                  }
                  final total = _total;
                  if (total <= 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextField(
                      controller: _cashCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Recibido del cliente',
                        hintText: CurrencyFormatter.format(total),
                        prefixIcon: const Icon(Icons.payments_outlined),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  );
                }),
                SizedBox(height: vPad),
                // Total a cobrar
                Builder(builder: (_) {
                  final total = _total;
                  final tooMuch = total > widget.maxAmount + 0.01;
                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total a cobrar',
                              style: theme.textTheme.titleSmall),
                          Flexible(
                            child: Text(
                              CurrencyFormatter.format(total),
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: tooMuch
                                    ? theme.colorScheme.error
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (tooMuch) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Supera el saldo '
                          '(${CurrencyFormatter.format(widget.maxAmount)})',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.error),
                        ),
                      ],
                    ],
                  );
                }),
                SizedBox(height: vPad),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _processing
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44)),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatefulBuilder(
                        builder: (_, ss) => FilledButton.icon(
                          icon: _processing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check, size: 18),
                          label: Text(
                            _processing
                                ? 'Procesando…'
                                : 'Cobrar ${CurrencyFormatter.format(_total)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: _processing ||
                                  _total <= 0 ||
                                  _total > widget.maxAmount + 0.01
                              ? null
                              : _confirm,
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 44)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  final _OrderSelectableItem selectable;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  const _OrderItemTile({
    required this.selectable,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = selectable.isSelected;
    final nameColor = active
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;
    final amtColor = active
        ? AppColors.primary
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectable.item.productName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: nameColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  CurrencyFormatter.format(selectable.item.unitPrice),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StepperBtn(icon: Icons.remove, onTap: onDecrement),
          SizedBox(
            width: 52,
            child: Text(
              '${selectable.selectedQty}/${selectable.item.quantity}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: amtColor,
              ),
            ),
          ),
          _StepperBtn(icon: Icons.add, onTap: onIncrement),
          const SizedBox(width: 8),
          SizedBox(
            width: 68,
            child: Text(
              CurrencyFormatter.format(selectable.subtotal),
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: amtColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepperBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: onTap == null
          ? theme.colorScheme.surfaceContainerHighest
          : AppColors.primary.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            icon,
            size: 16,
            color: onTap == null
                ? theme.colorScheme.onSurfaceVariant
                : AppColors.primary,
          ),
        ),
      ),
    );
  }
}
