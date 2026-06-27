import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/input_formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../cash_sessions/presentation/widgets/cash_session_error_handler.dart';
import '../../../cash_sessions/presentation/widgets/cash_session_required_banner.dart';
import '../../../payments/domain/usecases/process_tab_payment_usecase.dart';
import '../../../tenant_payment_accounts/domain/entities/tenant_payment_account.dart';
import '../../../tenant_payment_accounts/domain/usecases/tenant_payment_account_usecases.dart';
import '../../domain/entities/tab_session.dart';

/// Pantalla de cobro consolidado de una cuenta abierta.
///
/// El operario elige método + cuenta de pago + monto. El backend
/// distribuye FIFO entre los tickets pendientes (atómico).
///
/// UX:
/// - Por defecto el monto se pre-llena con el balance (caso 80%:
///   "pago todo").
/// - El operario puede bajarlo (cobro parcial — vuelve a la cuenta
///   con saldo).
/// - El total NO puede exceder el balance (validación local + server).
/// - Si paga el saldo entero, después del cobro se redirige al
///   detalle con un toast "¿Cerrar cuenta?".
class TabSessionPayPage extends StatefulWidget {
  const TabSessionPayPage({super.key});

  @override
  State<TabSessionPayPage> createState() => _TabSessionPayPageState();
}

class _TabSessionPayPageState extends State<TabSessionPayPage> {
  late final TabSession session;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _receivedCtrl;
  late final TextEditingController _referenceCtrl;
  late final TextEditingController _notesCtrl;

  PaymentMethod _selectedMethod = PaymentMethod.cash;
  TenantPaymentAccount? _selectedAccount;
  List<TenantPaymentAccount> _accounts = const [];
  bool _isLoadingAccounts = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    session = Get.arguments?['session'] as TabSession;
    _amountCtrl = TextEditingController(
      text: NumberFormatHelper.formatNumber(session.balance.round()),
    );
    _receivedCtrl = TextEditingController();
    _referenceCtrl = TextEditingController();
    _notesCtrl = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAccounts());
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _receivedCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    final useCases = sl<TenantPaymentAccountUseCases>();
    final result = await useCases.getAll(onlyActive: true);
    result.fold(
      (_) {},
      (list) {
        if (mounted) {
          setState(() {
            _accounts = list;
            _isLoadingAccounts = false;
          });
        }
      },
    );
  }

  List<TenantPaymentAccount> get _accountsForMethod => _accounts
      .where((a) => a.category == _selectedMethod && a.isActive)
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  double get _amount =>
      (NumberFormatHelper.parseFormattedInt(_amountCtrl.text) ?? 0).toDouble();

  double get _received =>
      (NumberFormatHelper.parseFormattedInt(_receivedCtrl.text) ?? 0)
          .toDouble();

  bool get _canSubmit {
    if (_amount <= 0) return false;
    if (_amount > session.balance + 0.01) return false;
    if (_selectedMethod == PaymentMethod.cash && _received > 0) {
      if (_received < _amount) return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit || _isProcessing) return;
    setState(() => _isProcessing = true);

    final useCase = sl<ProcessTabPaymentUseCase>();
    final result = await useCase(
      tabSessionId: session.id,
      amount: _amount,
      paymentMethod: _selectedMethod,
      tenantPaymentAccountId: _selectedAccount?.id,
      receivedAmount: _selectedMethod == PaymentMethod.cash && _received > 0
          ? _received
          : null,
      transactionReference: _referenceCtrl.text.trim().isEmpty
          ? null
          : _referenceCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    result.fold(
      (failure) {
        // Si el server rechazó por falta de caja, mostramos el dialog
        // amigable con "Abrir caja ahora" en lugar de un snackbar
        // críptico.
        if (isCashSessionRequiredError(failure.message)) {
          handleCashSessionError(failure.message);
          return;
        }
        AppSnackbar.show('Error al cobrar', failure.message);
      },
      (payments) {
        AppSnackbar.show(
          'Cobro exitoso',
          'Se distribuyó en ${payments.length} ${payments.length == 1 ? "ticket" : "tickets"}',
        );
        if (mounted) Navigator.of(context).pop(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _buildBalanceCard(),
                  const SizedBox(height: 20),
                  _buildSectionTitle('Monto a cobrar'),
                  const SizedBox(height: 8),
                  _buildAmountInput(),
                  const SizedBox(height: 20),
                  _buildSectionTitle('Método de pago'),
                  const SizedBox(height: 8),
                  _buildMethodSelector(),
                  // Banner que advierte si elige efectivo sin caja
                  // abierta — incluye botón inline para abrir caja
                  // sin abandonar el cobro consolidado.
                  CashSessionRequiredBanner(
                    isCashSelected: _selectedMethod == PaymentMethod.cash,
                  ),
                  const SizedBox(height: 16),
                  if (!_isLoadingAccounts && _accountsForMethod.isNotEmpty) ...[
                    _buildSectionTitle('¿En qué cuenta?'),
                    const SizedBox(height: 8),
                    _buildAccountSelector(),
                    const SizedBox(height: 16),
                  ],
                  if (_selectedMethod == PaymentMethod.cash) ...[
                    _buildSectionTitle('Recibido (opcional)'),
                    const SizedBox(height: 8),
                    _buildReceivedInput(),
                    if (_received > _amount) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Cambio: ${CurrencyFormatter.format(_received - _amount)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ] else ...[
                    _buildSectionTitle('Referencia (opcional)'),
                    const SizedBox(height: 8),
                    _buildReferenceInput(),
                    const SizedBox(height: 16),
                  ],
                  _buildSectionTitle('Notas (opcional)'),
                  const SizedBox(height: 8),
                  _buildNotesInput(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          // Obx para reaccionar al guard global de caja: si el cajero
          // abrió caja desde el banner inline sin cerrar esta pantalla,
          // el botón se rehabilita automáticamente.
          child: Obx(() {
            final cashOk = canSubmitWithCashGuard(
              _selectedMethod == PaymentMethod.cash,
            );
            final enabled = _canSubmit && !_isProcessing && cashOk;
            return FilledButton.icon(
              onPressed: enabled ? _submit : null,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      !cashOk ? Icons.lock_outline : Icons.check_circle,
                      size: 20,
                    ),
              label: Text(
                _isProcessing
                    ? 'Cobrando...'
                    : (!cashOk
                        ? 'Abrí caja para cobrar en efectivo'
                        : 'Cobrar ${CurrencyFormatter.format(_amount)}'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AppGradientHeader(
      title: 'Cobrar cuenta',
      subtitle: session.displayLabel(),
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total de la cuenta',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                CurrencyFormatter.format(session.totalAmount),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ya pagado',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                CurrencyFormatter.format(session.paidAmount),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pendiente',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                CurrencyFormatter.format(session.balance),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildAmountInput() {
    return TextField(
      controller: _amountCtrl,
      keyboardType: TextInputType.number,
      inputFormatters: [ThousandsSeparatorInputFormatter()],
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
      decoration: _inputDecoration(prefix: '\$ '),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildMethodSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: PaymentMethod.values.map((m) {
        return AppFilterChip(
          label: m.displayName,
          icon: _iconFor(m),
          selected: _selectedMethod == m,
          onTap: () => setState(() {
            _selectedMethod = m;
            _selectedAccount = null; // reset cuenta al cambiar método
          }),
        );
      }).toList(),
    );
  }

  Widget _buildAccountSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _accountsForMethod.map((acc) {
        final isSelected = _selectedAccount?.id == acc.id;
        return GestureDetector(
          onTap: () => setState(() {
            _selectedAccount = isSelected ? null : acc;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  acc.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                if (acc.accountNumber != null || acc.accountHolder != null)
                  Text(
                    [
                      if (acc.accountHolder != null) acc.accountHolder!,
                      if (acc.accountNumber != null) acc.accountNumber!,
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.85)
                          : AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReceivedInput() {
    return TextField(
      controller: _receivedCtrl,
      keyboardType: TextInputType.number,
      inputFormatters: [ThousandsSeparatorInputFormatter()],
      decoration: _inputDecoration(prefix: '\$ ', hint: 'Cuánto recibió'),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildReferenceInput() {
    return TextField(
      controller: _referenceCtrl,
      inputFormatters: [
        FilteringTextInputFormatter.deny(RegExp(r'[^A-Za-z0-9\-]')),
      ],
      decoration:
          _inputDecoration(hint: 'Voucher, ID transacción, etc.'),
    );
  }

  Widget _buildNotesInput() {
    return TextField(
      controller: _notesCtrl,
      maxLines: 2,
      decoration: _inputDecoration(hint: 'Detalle interno'),
    );
  }

  InputDecoration _inputDecoration({String? prefix, String? hint}) =>
      InputDecoration(
        prefixText: prefix,
        hintText: hint,
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

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
      case PaymentMethod.nequi:
        return Icons.qr_code_2;
    }
  }
}
