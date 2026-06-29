import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/input_formatters.dart';
import 'payment_method_selector.dart';
import '../../../../core/widgets/modern_card.dart';
import '../../../cash_sessions/presentation/widgets/cash_session_required_banner.dart';
import '../../../tenant_payment_accounts/domain/entities/tenant_payment_account.dart';
import '../../../tenant_payment_accounts/domain/usecases/tenant_payment_account_usecases.dart';
import '../../domain/entities/payment.dart';
import '../controllers/payment_controller.dart';

/// Dialog de pagos parciales (anteriormente "Dividir Pago").
///
/// **Cambio de modelo (importante):**
///
/// Antes era un "batch": el cajero agregaba N pagos a una lista en memoria y
/// luego presionaba "Confirmar" para enviarlos todos juntos al backend.
/// Si cerraba el dialog antes de confirmar, **el dinero recibido se perdía**
/// del sistema (aunque ya estuviera en su mano y en caja física).
///
/// Ahora cada "Agregar Pago" hace POST inmediato al backend (vía
/// `PaymentController.addPartialPayment`). Cada cobro parcial queda
/// **persistido al instante** — si el cajero cierra el dialog o se va,
/// no se pierde nada. El backend valida en cada request que
/// `sum(payments) <= total` y, cuando llegan al total, marca la orden
/// como `payment_status = completed` automáticamente.
///
/// La lista visible son los `controller.payments` reales (lo que el
/// backend conoce), no un cache local.
class SplitPaymentDialog extends StatefulWidget {
  /// ID de la orden a cobrar. Cada "Agregar Pago" lo usa para hacer
  /// `POST /payments` con el order_id correcto.
  final String orderId;
  final double totalAmount;
  final PaymentController controller;

  const SplitPaymentDialog({
    super.key,
    required this.orderId,
    required this.totalAmount,
    required this.controller,
  });

  @override
  State<SplitPaymentDialog> createState() => _SplitPaymentDialogState();
}

class _SplitPaymentDialogState extends State<SplitPaymentDialog> {
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _receivedController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Cuentas activas del tenant — cargadas una vez al abrir.
  List<TenantPaymentAccount> _tenantAccounts = const [];
  TenantPaymentAccount? _selectedTenantAccount;

  /// Total ya cobrado (suma de payments completed reales del backend).
  double get _paidAmount => widget.controller.payments
      .where((p) => p.status == PaymentStatus.completed)
      .fold<double>(0, (sum, p) => sum + p.amount);

  /// Lo que falta cobrar de esta orden.
  double get _remainingAmount {
    final r = widget.totalAmount - _paidAmount;
    return r < 0 ? 0 : r;
  }

  bool get _isFullyPaid => _remainingAmount <= 0.01;

  /// El monto del nuevo pago a registrar.
  double get _newAmount =>
      (NumberFormatHelper.parseFormattedInt(_amountController.text) ?? 0)
          .toDouble();

  /// Si es cash, el "recibido" puede ser mayor (calculamos cambio).
  /// Opcional — si está vacío, asumimos que recibimos exacto.
  double get _receivedAmount =>
      (NumberFormatHelper.parseFormattedInt(_receivedController.text) ?? 0)
          .toDouble();

  bool get _canAddPayment {
    if (_isFullyPaid) return false;
    if (_newAmount <= 0) return false;
    // Tolerancia de 1 centavo para evitar bloquear por redondeos.
    if (_newAmount > _remainingAmount + 0.01) return false;
    if (_selectedMethod == PaymentMethod.cash && _receivedAmount > 0) {
      if (_receivedAmount < _newAmount) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_rebuild);
    _receivedController.addListener(_rebuild);
    // Cargamos los payments ya existentes del backend para que la lista
    // y el remaining arranquen correctos. Esto cubre el caso de reentrar
    // al dialog: si ya cobramos $2k antes, los vemos al volver.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadPaymentsByOrder(widget.orderId);
    });
    _loadTenantAccounts();
  }

  Future<void> _loadTenantAccounts() async {
    final useCases = sl<TenantPaymentAccountUseCases>();
    final result = await useCases.getAll(onlyActive: true);
    result.fold(
      (_) {},
      (list) {
        if (mounted) setState(() => _tenantAccounts = list);
      },
    );
  }

  List<TenantPaymentAccount> get _accountsForCurrentMethod => _tenantAccounts
      .where((a) => a.category == _selectedMethod && a.isActive)
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amountController.removeListener(_rebuild);
    _receivedController.removeListener(_rebuild);
    _amountController.dispose();
    _receivedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _addPayment() async {
    if (!_canAddPayment) return;

    final isCash = _selectedMethod == PaymentMethod.cash;
    final amount = _newAmount;
    final received = isCash && _receivedAmount > 0 ? _receivedAmount : null;

    final payment = await widget.controller.addPartialPayment(
      orderId: widget.orderId,
      paymentMethod: _selectedMethod,
      amount: amount,
      receivedAmount: received,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      tenantPaymentAccountId: _selectedTenantAccount?.id,
    );

    if (payment == null) return; // Falló (snackbar / dialog ya se mostró).

    if (!mounted) return;

    // Cerramos el dialog devolviendo los payments al caller (el detalle
    // de la orden), que refresca el saldo restante. El pago ya quedó
    // PERSISTIDO en el backend —así sea un abono parcial— por
    // `addPartialPayment`. Si el cajero quiere registrar otro abono,
    // reabre "Procesar pago" y verá el restante ya descontado.
    Navigator.pop(context, widget.controller.payments.toList());
  }

  void _useRemainingAsAmount() {
    _amountController.text =
        NumberFormatHelper.formatNumber(_remainingAmount.round());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = MediaQuery.of(context).size;
    final maxW = screen.width < 600
        ? screen.width * 0.92
        : (screen.width < 900 ? 480.0 : 520.0);
    final maxH = screen.height < 700 ? screen.height * 0.92 : 720.0;

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
            _buildHeader(theme),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(() => _buildBalanceCard(theme)),
                    const SizedBox(height: 20),
                    if (!_isFullyPaid) ...[
                      Text(
                        'Registrar nuevo pago',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cada pago queda guardado al instante. Si te '
                        'interrumpen, el dinero ya está en caja.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildCompactMethodSelector(theme),
                      _buildTenantAccountSelector(theme),
                      CashSessionRequiredBanner(
                        isCashSelected:
                            _selectedMethod == PaymentMethod.cash,
                      ),
                      const SizedBox(height: 16),
                      _buildAmountRow(theme),
                      if (_selectedMethod == PaymentMethod.cash) ...[
                        const SizedBox(height: 12),
                        _buildReceivedRow(theme),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          labelText: 'Notas (opcional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),
                      _buildAddButton(),
                      const SizedBox(height: 24),
                    ],
                    Obx(() => _buildPaymentsList(theme)),
                  ],
                ),
              ),
            ),
            _buildFooter(theme),
          ],
        ),
      ),
    );
  }

  // ─────────────────────── Pieces ─────────────────────────

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Icon(Icons.splitscreen,
              color: theme.colorScheme.onPrimaryContainer, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dividir pago',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  'Total: ${CurrencyFormatter.format(widget.totalAmount)}',
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
            onPressed: () => Navigator.pop(
              context,
              widget.controller.payments.toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(ThemeData theme) {
    final complete = _isFullyPaid;
    return ModernCard(
      gradient: LinearGradient(
        colors: complete
            ? [Colors.green.shade300, Colors.green.shade500]
            : [
                theme.colorScheme.secondaryContainer,
                theme.colorScheme.tertiaryContainer
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _balanceRow(
              'Total orden',
              CurrencyFormatter.format(widget.totalAmount),
              theme,
            ),
            const SizedBox(height: 6),
            _balanceRow(
              'Ya pagado',
              CurrencyFormatter.format(_paidAmount),
              theme,
            ),
            const Divider(color: Colors.white24, height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  complete ? 'Pago completo' : 'Falta',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Row(
                  children: [
                    if (complete)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.check_circle,
                            color: Colors.white, size: 22),
                      ),
                    Text(
                      complete
                          ? 'Listo'
                          : CurrencyFormatter.format(_remainingAmount),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceRow(String label, String value, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountRow(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Monto a cobrar',
              prefixText: '\$ ',
              hintText: '0',
              helperText:
                  _newAmount > _remainingAmount && _remainingAmount > 0
                      ? 'Excede el restante (${CurrencyFormatter.format(_remainingAmount)})'
                      : 'Máximo: ${CurrencyFormatter.format(_remainingAmount)}',
              helperStyle: TextStyle(
                color: _newAmount > _remainingAmount && _remainingAmount > 0
                    ? theme.colorScheme.error
                    : null,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsSeparatorInputFormatter()],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.tonal(
          onPressed: _remainingAmount > 0 ? _useRemainingAsAmount : null,
          child: const Text('Todo'),
        ),
      ],
    );
  }

  Widget _buildReceivedRow(ThemeData theme) {
    final change =
        _receivedAmount > _newAmount ? _receivedAmount - _newAmount : 0;
    return Column(
      children: [
        TextField(
          controller: _receivedController,
          decoration: InputDecoration(
            labelText: 'Recibido (opcional)',
            prefixText: '\$ ',
            hintText: 'Cuánto entregó el cliente',
            helperText:
                'Vacío = recibe exacto. Si recibió más, te calculamos el cambio.',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsSeparatorInputFormatter()],
        ),
        if (change > 0) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Cambio: ${CurrencyFormatter.format(change.toDouble())}',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAddButton() {
    return Obx(() {
      final cashOk = canSubmitWithCashGuard(
        _selectedMethod == PaymentMethod.cash,
      );
      final processing = widget.controller.isProcessing.value;
      final enabled = _canAddPayment && cashOk && !processing;
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: enabled ? _addPayment : null,
          icon: processing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(!cashOk ? Icons.lock_outline : Icons.add_circle),
          label: Text(
            processing
                ? 'Registrando…'
                : (!cashOk
                    ? 'Abrí caja para registrar efectivo'
                    : 'Registrar pago'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      );
    });
  }

  Widget _buildPaymentsList(ThemeData theme) {
    final list = widget.controller.payments
        .where((p) => p.status == PaymentStatus.completed)
        .toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pagos registrados (${list.length})',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ...list.map((p) => _buildPaymentItem(theme, p)),
      ],
    );
  }

  Widget _buildPaymentItem(ThemeData theme, Payment p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(paymentMethodIcon(p.paymentMethod), color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paymentMethodName(p.paymentMethod),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (p.notes != null && p.notes!.isNotEmpty)
                  Text(
                    p.notes!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.format(p.amount),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, safeBottom + 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.check),
          label: Text(_isFullyPaid ? 'Listo' : 'Cerrar'),
          onPressed: () => Navigator.pop(
            context,
            widget.controller.payments.toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactMethodSelector(ThemeData theme) {
    return PaymentMethodSelector(
      selectedMethod: _selectedMethod,
      onMethodSelected: (m) => setState(() {
        _selectedMethod = m;
        _selectedTenantAccount = null;
      }),
    );
  }

  Widget _buildTenantAccountSelector(ThemeData theme) {
    final accounts = _accountsForCurrentMethod;
    if (accounts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿En qué cuenta?',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: accounts.map((acc) {
              final selected = _selectedTenantAccount?.id == acc.id;
              return Material(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() {
                    _selectedTenantAccount = selected ? null : acc;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      acc.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

}
