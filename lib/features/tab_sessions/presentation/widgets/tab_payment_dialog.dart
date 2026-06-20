import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/input_formatters.dart';
import '../../../../core/widgets/app_filter_chip.dart';
import '../../../../core/widgets/modern_card.dart';
import '../../../cash_sessions/presentation/widgets/cash_session_error_handler.dart';
import '../../../cash_sessions/presentation/widgets/cash_session_required_banner.dart';
import '../../../payments/domain/usecases/process_tab_payment_usecase.dart';
import '../../../tenant_payment_accounts/domain/entities/tenant_payment_account.dart';
import '../../../tenant_payment_accounts/domain/usecases/tenant_payment_account_usecases.dart';
import '../../domain/entities/tab_session.dart';

/// Cobro de una cuenta abierta — MISMO flujo de dos pasos que una orden:
///
///   1. `TabPaymentDialog` (este): chooser con "Cobrar todo" (paga el
///      saldo completo) + botón **"Dividir cuenta"** — igual que el
///      `ProcessPaymentDialog` de orden con su "Dividir Pago".
///   2. `_TabSplitPaymentDialog`: pagos parciales múltiples (dividir),
///      espejo del `SplitPaymentDialog` de orden.
///
/// Por debajo usa `ProcessTabPaymentUseCase` (POST /payments/tab/:id),
/// que distribuye FIFO entre los tickets. Devuelve `true` por
/// `Navigator.pop` si se cobró algo (el caller recarga la cuenta).
class TabPaymentDialog extends StatefulWidget {
  final TabSession session;

  const TabPaymentDialog({super.key, required this.session});

  @override
  State<TabPaymentDialog> createState() => _TabPaymentDialogState();
}

class _TabPaymentDialogState extends State<TabPaymentDialog> {
  final TextEditingController _receivedCtrl = TextEditingController();
  final TextEditingController _referenceCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  PaymentMethod _selectedMethod = PaymentMethod.cash;
  TenantPaymentAccount? _selectedAccount;
  List<TenantPaymentAccount> _accounts = const [];
  bool _isProcessing = false;

  TabSession get session => widget.session;

  /// El chooser cobra el SALDO completo de la cuenta de una.
  double get _amount => session.balance;

  double get _received =>
      (NumberFormatHelper.parseFormattedInt(_receivedCtrl.text) ?? 0)
          .toDouble();

  bool get _canSubmit {
    if (_amount <= 0) return false;
    if (_selectedMethod == PaymentMethod.cash && _received > 0) {
      if (_received < _amount) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _receivedCtrl.addListener(_rebuild);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAccounts());
  }

  @override
  void dispose() {
    _receivedCtrl.removeListener(_rebuild);
    _receivedCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAccounts() async {
    final useCases = sl<TenantPaymentAccountUseCases>();
    final result = await useCases.getAll(onlyActive: true);
    result.fold((_) {}, (list) {
      if (mounted) setState(() => _accounts = list);
    });
  }

  List<TenantPaymentAccount> get _accountsForMethod => _accounts
      .where((a) => a.category == _selectedMethod && a.isActive)
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  Future<void> _payFull() async {
    if (!_canSubmit || _isProcessing) return;
    setState(() => _isProcessing = true);

    final isCash = _selectedMethod == PaymentMethod.cash;
    final useCase = sl<ProcessTabPaymentUseCase>();
    final result = await useCase(
      tabSessionId: session.id,
      amount: _amount,
      paymentMethod: _selectedMethod,
      tenantPaymentAccountId: _selectedAccount?.id,
      receivedAmount: isCash && _received > 0 ? _received : null,
      transactionReference: _referenceCtrl.text.trim().isEmpty
          ? null
          : _referenceCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    result.fold(
      (failure) {
        if (isCashSessionRequiredError(failure.message)) {
          handleCashSessionError(failure.message);
          return;
        }
        AppSnackbar.show('Error al cobrar', failure.message);
      },
      (payments) {
        AppSnackbar.show('Cobro exitoso', 'Cuenta cobrada completa');
        if (mounted) Navigator.of(context).pop(true);
      },
    );
  }

  Future<void> _openSplit() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => _TabSplitPaymentDialog(session: session),
    );
    // Si en el split se registró algún pago, cerramos el chooser también
    // devolviendo true para que el caller recargue la cuenta.
    if (res == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = MediaQuery.of(context).size;
    final maxW = screen.width < 600
        ? screen.width * 0.92
        : (screen.width < 900 ? 480.0 : 500.0);
    final maxH = screen.height < 700 ? screen.height * 0.92 : 700.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: screen.width < 600 ? 16 : 40,
        vertical: screen.height < 700 ? 16 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Column(
          children: [
            _Header(
              title: 'Cobrar cuenta',
              subtitle:
                  '${session.displayLabel()} · A cobrar ${CurrencyFormatter.format(_amount)}',
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BalanceCard(session: session, paidExtra: 0),
                    const SizedBox(height: 18),
                    _SectionTitle('Método de pago'),
                    const SizedBox(height: 8),
                    _MethodSelector(
                      selected: _selectedMethod,
                      onSelect: (m) => setState(() {
                        _selectedMethod = m;
                        _selectedAccount = null;
                      }),
                    ),
                    _AccountSelector(
                      accounts: _accountsForMethod,
                      selected: _selectedAccount,
                      onSelect: (a) => setState(() => _selectedAccount = a),
                    ),
                    CashSessionRequiredBanner(
                      isCashSelected: _selectedMethod == PaymentMethod.cash,
                    ),
                    const SizedBox(height: 16),
                    if (_selectedMethod == PaymentMethod.cash) ...[
                      _SectionTitle('Recibido (opcional)'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _receivedCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [ThousandsSeparatorInputFormatter()],
                        decoration: _inputDecoration(
                            prefix: '\$ ', hint: 'Cuánto entregó el cliente'),
                      ),
                      if (_received > _amount) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Cambio: ${CurrencyFormatter.format(_received - _amount)}',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ] else ...[
                      _SectionTitle('Referencia (opcional)'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _referenceCtrl,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(
                              RegExp(r'[^A-Za-z0-9\-]')),
                        ],
                        decoration: _inputDecoration(
                            hint: 'Voucher, ID transacción, etc.'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _SectionTitle('Notas (opcional)'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      decoration: _inputDecoration(hint: 'Detalle interno'),
                    ),
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

  Widget _buildFooter(ThemeData theme) {
    final cashOk =
        canSubmitWithCashGuard(_selectedMethod == PaymentMethod.cash);
    final enabled = _canSubmit && !_isProcessing && cashOk;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dividir cuenta — igual que el "Dividir Pago" de una orden.
          OutlinedButton.icon(
            icon: const Icon(Icons.splitscreen),
            label: const Text('Dividir cuenta'),
            onPressed: _isProcessing ? null : _openSplit,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: enabled ? _payFull : null,
            icon: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Icon(!cashOk ? Icons.lock_outline : Icons.check_circle),
            label: Text(
              _isProcessing
                  ? 'Cobrando...'
                  : (!cashOk
                      ? 'Abrí caja para cobrar en efectivo'
                      : 'Cobrar todo ${CurrencyFormatter.format(_amount)}'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ Split (dividir cuenta) ════════════════════════

/// Un pago registrado en ESTA sesión del dialog (para la lista visible).
class _TabReg {
  final PaymentMethod method;
  final double amount;
  final String? notes;
  const _TabReg(this.method, this.amount, this.notes);
}

/// Pagos parciales múltiples de una cuenta — espejo del `SplitPaymentDialog`
/// de orden. Registrás N pagos (cada uno persiste FIFO), con saldo en vivo,
/// "Todo" = restante, efectivo+cambio. Cuando el saldo llega a 0 cierra.
/// Devuelve `true` si se registró al menos un pago.
class _TabSplitPaymentDialog extends StatefulWidget {
  final TabSession session;
  const _TabSplitPaymentDialog({required this.session});

  @override
  State<_TabSplitPaymentDialog> createState() => _TabSplitPaymentDialogState();
}

class _TabSplitPaymentDialogState extends State<_TabSplitPaymentDialog> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _receivedCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  PaymentMethod _selectedMethod = PaymentMethod.cash;
  TenantPaymentAccount? _selectedAccount;
  List<TenantPaymentAccount> _accounts = const [];
  bool _isProcessing = false;
  final List<_TabReg> _registered = [];

  TabSession get session => widget.session;

  double get _paidAmount =>
      session.paidAmount + _registered.fold<double>(0, (s, r) => s + r.amount);

  double get _remaining {
    final r = session.totalAmount - _paidAmount;
    return r < 0 ? 0 : r;
  }

  bool get _isFullyPaid => _remaining <= 0.01;

  double get _newAmount =>
      (NumberFormatHelper.parseFormattedInt(_amountCtrl.text) ?? 0).toDouble();

  double get _received =>
      (NumberFormatHelper.parseFormattedInt(_receivedCtrl.text) ?? 0)
          .toDouble();

  bool get _canRegister {
    if (_isFullyPaid) return false;
    if (_newAmount <= 0) return false;
    if (_newAmount > _remaining + 0.01) return false;
    if (_selectedMethod == PaymentMethod.cash && _received > 0) {
      if (_received < _newAmount) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_rebuild);
    _receivedCtrl.addListener(_rebuild);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAccounts());
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_rebuild);
    _receivedCtrl.removeListener(_rebuild);
    _amountCtrl.dispose();
    _receivedCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAccounts() async {
    final useCases = sl<TenantPaymentAccountUseCases>();
    final result = await useCases.getAll(onlyActive: true);
    result.fold((_) {}, (list) {
      if (mounted) setState(() => _accounts = list);
    });
  }

  List<TenantPaymentAccount> get _accountsForMethod => _accounts
      .where((a) => a.category == _selectedMethod && a.isActive)
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  void _useRemainingAsAmount() {
    _amountCtrl.text = NumberFormatHelper.formatNumber(_remaining.round());
  }

  Future<void> _register() async {
    if (!_canRegister || _isProcessing) return;
    setState(() => _isProcessing = true);

    final isCash = _selectedMethod == PaymentMethod.cash;
    final amount = _newAmount;
    final received = isCash && _received > 0 ? _received : null;
    final notes = _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

    final useCase = sl<ProcessTabPaymentUseCase>();
    final result = await useCase(
      tabSessionId: session.id,
      amount: amount,
      paymentMethod: _selectedMethod,
      tenantPaymentAccountId: _selectedAccount?.id,
      receivedAmount: received,
      notes: notes,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    result.fold(
      (failure) {
        if (isCashSessionRequiredError(failure.message)) {
          handleCashSessionError(failure.message);
          return;
        }
        AppSnackbar.show('Error al cobrar', failure.message);
      },
      (payments) {
        _registered.add(_TabReg(_selectedMethod, amount, notes));
        AppSnackbar.show(
          'Pago registrado',
          '${_selectedMethod.displayName} · ${CurrencyFormatter.format(amount)}',
        );
        // Igual que el "Dividir" de una orden: el pago ya quedó PERSISTIDO
        // (FIFO), así que cerramos devolviendo true. El caller recarga la
        // cuenta; si fue parcial, al reabrir "Cobrar" se ve el saldo
        // restante y se cobra el resto (incluso con otro método).
        if (mounted) Navigator.of(context).pop(true);
      },
    );
  }

  void _close() => Navigator.of(context).pop(_registered.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = MediaQuery.of(context).size;
    final maxW = screen.width < 600
        ? screen.width * 0.92
        : (screen.width < 900 ? 480.0 : 520.0);
    final maxH = screen.height < 700 ? screen.height * 0.92 : 720.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: screen.width < 600 ? 16 : 40,
        vertical: screen.height < 700 ? 16 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Column(
          children: [
            _Header(
              title: 'Dividir cuenta',
              subtitle:
                  '${session.displayLabel()} · Total ${CurrencyFormatter.format(session.totalAmount)}',
              onClose: _close,
              icon: Icons.splitscreen,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BalanceCard(
                      session: session,
                      paidExtra:
                          _registered.fold<double>(0, (s, r) => s + r.amount),
                    ),
                    const SizedBox(height: 20),
                    if (!_isFullyPaid) ...[
                      Text('Registrar pago',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        'Cada pago queda guardado al instante. Cobrá en '
                        'varias partes (efectivo, tarjeta, etc.).',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _MethodSelector(
                        selected: _selectedMethod,
                        onSelect: (m) => setState(() {
                          _selectedMethod = m;
                          _selectedAccount = null;
                        }),
                      ),
                      _AccountSelector(
                        accounts: _accountsForMethod,
                        selected: _selectedAccount,
                        onSelect: (a) => setState(() => _selectedAccount = a),
                      ),
                      CashSessionRequiredBanner(
                        isCashSelected: _selectedMethod == PaymentMethod.cash,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _amountCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                ThousandsSeparatorInputFormatter()
                              ],
                              decoration: _inputDecoration(
                                label: 'Monto a cobrar',
                                prefix: '\$ ',
                                hint: '0',
                                helper:
                                    'Máximo: ${CurrencyFormatter.format(_remaining)}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.tonal(
                            onPressed:
                                _remaining > 0 ? _useRemainingAsAmount : null,
                            child: const Text('Todo'),
                          ),
                        ],
                      ),
                      if (_selectedMethod == PaymentMethod.cash) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _receivedCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [ThousandsSeparatorInputFormatter()],
                          decoration: _inputDecoration(
                              label: 'Recibido (opcional)',
                              prefix: '\$ ',
                              hint: 'Cuánto entregó'),
                        ),
                        if (_received > _newAmount) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Cambio: ${CurrencyFormatter.format(_received - _newAmount)}',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesCtrl,
                        decoration: _inputDecoration(hint: 'Notas (opcional)'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),
                      _buildRegisterButton(),
                      const SizedBox(height: 20),
                    ],
                    _buildRegisteredList(theme),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.check),
                  label: Text(_isFullyPaid ? 'Listo' : 'Cerrar'),
                  onPressed: _close,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterButton() {
    final cashOk =
        canSubmitWithCashGuard(_selectedMethod == PaymentMethod.cash);
    final enabled = _canRegister && cashOk && !_isProcessing;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: enabled ? _register : null,
        icon: _isProcessing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(!cashOk ? Icons.lock_outline : Icons.add_circle),
        label: Text(
          _isProcessing
              ? 'Registrando…'
              : (!cashOk ? 'Abrí caja para registrar efectivo' : 'Registrar pago'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildRegisteredList(ThemeData theme) {
    if (_registered.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pagos registrados (${_registered.length})',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ..._registered.map((r) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(_iconFor(r.method), color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(r.method.displayName,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  Text(
                    CurrencyFormatter.format(r.amount),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

// ════════════════════════ Piezas compartidas ════════════════════════

IconData _iconFor(PaymentMethod m) {
  switch (m) {
    case PaymentMethod.cash:
      return Icons.payments_outlined;
    case PaymentMethod.card:
      return Icons.credit_card_outlined;
    case PaymentMethod.transfer:
      return Icons.account_balance_outlined;
    case PaymentMethod.digitalWallet:
      return Icons.account_balance_wallet_outlined;
  }
}

InputDecoration _inputDecoration({
  String? label,
  String? prefix,
  String? hint,
  String? helper,
}) =>
    InputDecoration(
      labelText: label,
      prefixText: prefix,
      hintText: hint,
      helperText: helper,
      filled: true,
      fillColor: AppColors.cardBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final IconData icon;
  const _Header({
    required this.title,
    required this.subtitle,
    required this.onClose,
    this.icon = Icons.payment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onPrimaryContainer, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    )),
                Text(subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: onClose),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final TabSession session;
  final double paidExtra;
  const _BalanceCard({required this.session, required this.paidExtra});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paid = session.paidAmount + paidExtra;
    final remaining = (session.totalAmount - paid).clamp(0, double.infinity);
    final complete = remaining <= 0.01;
    return ModernCard(
      gradient: LinearGradient(
        colors: complete
            ? [Colors.green.shade300, Colors.green.shade500]
            : [
                theme.colorScheme.secondaryContainer,
                theme.colorScheme.tertiaryContainer,
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row('Total cuenta', CurrencyFormatter.format(session.totalAmount)),
            const SizedBox(height: 6),
            _row('Ya pagado', CurrencyFormatter.format(paid)),
            const Divider(color: Colors.white24, height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(complete ? 'Pago completo' : 'Falta',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    )),
                Text(
                  complete
                      ? 'Listo'
                      : CurrencyFormatter.format(remaining.toDouble()),
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
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);
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

class _MethodSelector extends StatelessWidget {
  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onSelect;
  const _MethodSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: PaymentMethod.values.map((m) {
        return AppFilterChip(
          label: m.displayName,
          icon: _iconFor(m),
          selected: selected == m,
          onTap: () => onSelect(m),
        );
      }).toList(),
    );
  }
}

class _AccountSelector extends StatelessWidget {
  final List<TenantPaymentAccount> accounts;
  final TenantPaymentAccount? selected;
  final ValueChanged<TenantPaymentAccount?> onSelect;
  const _AccountSelector({
    required this.accounts,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('¿En qué cuenta?'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: accounts.map((acc) {
              final isSelected = selected?.id == acc.id;
              return GestureDetector(
                onTap: () => onSelect(isSelected ? null : acc),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    acc.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color:
                          isSelected ? Colors.white : AppColors.textPrimary,
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
