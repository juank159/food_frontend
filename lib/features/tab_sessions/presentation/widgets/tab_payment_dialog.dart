import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/input_formatters.dart';
import '../../../payments/presentation/controllers/breb_payment_controller.dart';
import '../../../payments/presentation/widgets/breb_payment_dialog.dart';
import '../../../payments/presentation/widgets/item_selection_sheet.dart';
import '../../../payments/presentation/widgets/payment_method_selector.dart';
import '../../../../core/widgets/modern_card.dart';
import '../../../cash_sessions/presentation/widgets/cash_session_error_handler.dart';
import '../../../cash_sessions/presentation/widgets/cash_session_required_banner.dart';
import '../../../payments/domain/usecases/process_tab_payment_usecase.dart';
import '../../../printer_configs/data/printing_orchestrator.dart';
import '../../../tenant_payment_accounts/domain/entities/tenant_payment_account.dart';
import '../../../tenant_payment_accounts/domain/usecases/tenant_payment_account_usecases.dart';
import '../../domain/entities/tab_session.dart';

/// Cobro de una cuenta abierta — un solo diálogo, sin pasos anidados.
///
/// El monto es editable (precargado con el saldo completo, así que
/// cobrar todo sigue siendo un solo toque) y funciona con cualquier
/// método, incluido Bre-B. Si el cajero baja el monto (ej. "el cliente
/// paga 30 de 50"), el pago queda registrado igual y el diálogo se
/// cierra — al reabrir "Cobrar cuenta" para el resto, el saldo ya sale
/// actualizado. Antes esto vivía en un segundo diálogo separado
/// ("Dividir cuenta"), que quedó redundante en cuanto el monto se hizo
/// editable acá mismo — se eliminó.
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
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _receivedCtrl = TextEditingController();
  final TextEditingController _referenceCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  PaymentMethod _selectedMethod = PaymentMethod.cash;
  TenantPaymentAccount? _selectedAccount;
  List<TenantPaymentAccount> _accounts = const [];
  bool _isProcessing = false;

  TabSession get session => widget.session;

  /// Monto a cobrar — precargado con el saldo completo (el flujo de
  /// siempre sigue funcionando igual con un solo toque), pero editable:
  /// si el cliente dice "pago 30 de 50", el cajero lo cambia acá mismo
  /// sin tener que entrar a "Dividir cuenta". Funciona con cualquier
  /// método, incluido Bre-B (el backend ya acepta un monto parcial, ver
  /// `processTabPayment`/`BrebService.createCharge`).
  double get _amount =>
      (NumberFormatHelper.parseFormattedInt(_amountCtrl.text) ?? 0)
          .toDouble();

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

  void _useFullBalance() {
    _amountCtrl.text = NumberFormatHelper.formatNumber(session.balance.round());
  }

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = NumberFormatHelper.formatNumber(session.balance.round());
    _amountCtrl.addListener(_rebuild);
    _receivedCtrl.addListener(_rebuild);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAccounts());
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_rebuild);
    _amountCtrl.dispose();
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

  // Bre-B no tiene "cuenta" seleccionable acá: la config real vive en las
  // llaves (Ajustes → Bre-B) y el cobro nunca usa lo que se elija en este
  // selector para ese método — mostrarlo era un control que no hacía nada.
  List<TenantPaymentAccount> get _accountsForMethod =>
      _selectedMethod == PaymentMethod.brebB
          ? const []
          : (_accounts
              .where((a) => a.category == _selectedMethod && a.isActive)
              .toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)));

  Future<void> _processPayment() async {
    if (!_canSubmit || _isProcessing) return;

    // Cubre TODO lo que falta de la cuenta — recién ahí se puede
    // considerar "cobrada completa" e imprimir el recibo final. Si el
    // cajero bajó el monto (pago parcial), NO es el caso.
    final isFullPayment = _amount >= session.balance - 0.01;

    if (_selectedMethod == PaymentMethod.brebB) {
      await _processBrebPayment(_amount, isFullPayment: isFullPayment);
      return;
    }

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
        if (isFullPayment) {
          AppSnackbar.show('Cobro exitoso', 'Cuenta cobrada completa');
          // Cobro total — todos los tickets de la cuenta quedaron pagados.
          PrintingOrchestrator.autoPrintTabSessionReceipt(session);
        } else {
          AppSnackbar.show(
            'Pago registrado',
            '${CurrencyFormatter.format(_amount)} cobrado · queda '
                '${CurrencyFormatter.format(session.balance - _amount)} pendiente',
          );
        }
        if (mounted) Navigator.of(context).pop(true);
      },
    );
  }

  /// Bre-B no es un cobro sincrónico como los demás métodos: el backend
  /// solo registra el pago cuando concilia el correo de confirmación
  /// bancaria (ver `breb.service.ts`). Antes, elegir "Bre-B" acá caía
  /// directo en `ProcessTabPaymentUseCase` igual que efectivo/tarjeta —
  /// eso creaba un pago "completed" sin que ninguna plata real hubiera
  /// llegado, saltándose toda la verificación por correo que existe
  /// justamente para evitar marcar cuentas como pagadas sin cobrar de
  /// verdad. Ahora abre el mismo diálogo de espera (llave + confirmación
  /// real) que usa el cobro de una orden puntual.
  Future<void> _processBrebPayment(
    double amount, {
    required bool isFullPayment,
  }) async {
    final outerContext = context;
    final brebCtrl = BrebPaymentController(dio: sl<Dio>());
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BrebPaymentDialog(
        controller: brebCtrl,
        tabSessionId: session.id,
        amount: amount,
      ),
    );
    brebCtrl.cancel();
    if ((confirmed ?? false) && outerContext.mounted) {
      HapticFeedback.mediumImpact();
      if (isFullPayment) {
        // Mismo comportamiento que el cobro no-Bre-B: si esto cubrió todo
        // lo que faltaba, imprimir el recibo final de una vez.
        PrintingOrchestrator.autoPrintTabSessionReceipt(session);
      } else {
        AppSnackbar.show(
          'Pago registrado',
          '${CurrencyFormatter.format(amount)} cobrado · queda '
              '${CurrencyFormatter.format(session.balance - amount)} pendiente',
        );
      }
      Navigator.of(outerContext).pop(true);
    }
  }

  static double _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  Future<void> _openItemSelection() async {
    // Construir la lista de ítems con tracking de pagados por ítem
    final items = <SelectableItemEntry>[];
    int orderIndex = 1;
    for (final orderRaw in session.orders) {
      final order = orderRaw as Map<String, dynamic>?;
      if (order == null) continue;
      final orderNum =
          order['order_number']?.toString() ?? 'Ticket $orderIndex';
      final label = 'Ticket #$orderNum';

      // Calcular qty pagado por ítem desde los notes de cada pago
      final paidQtyById = <String, int>{};
      final paymentsRaw = order['payments'] as List<dynamic>? ?? [];
      for (final pRaw in paymentsRaw) {
        final p = pRaw as Map<String, dynamic>?;
        if (p == null) continue;
        if (p['status'] != 'completed') continue;
        try {
          final decoded =
              jsonDecode(p['notes'] as String? ?? '') as Map<String, dynamic>?;
          final iList = decoded?['__items__'] as List?;
          if (iList != null) {
            for (final raw in iList) {
              final m = raw as Map<String, dynamic>;
              final id = m['id'] as String?;
              final qty = (m['qty'] as num?)?.toInt() ?? 0;
              if (id != null) paidQtyById[id] = (paidQtyById[id] ?? 0) + qty;
            }
          }
        } catch (_) {}
      }

      final itemsList = order['items'] as List<dynamic>? ?? [];
      for (final itemRaw in itemsList) {
        final item = itemRaw as Map<String, dynamic>?;
        if (item == null) continue;
        final product = item['product'] as Map<String, dynamic>?;
        final variant = item['variant'] as Map<String, dynamic>?;
        final name = (item['product_name'] as String?) ??
            product?['name'] as String? ??
            '—';
        final variantName = variant?['name'] as String?;
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        final unitPrice = _parseNum(item['unit_price']);
        final itemId = item['id'] as String? ?? '';
        items.add(SelectableItemEntry(
          itemId: itemId,
          orderLabel: label,
          name: name,
          variantName: variantName,
          unitPrice: unitPrice,
          totalQty: qty,
          paidQty: paidQtyById[itemId] ?? 0,
        ));
      }
      orderIndex++;
    }

    if (!mounted) return;
    final useCase = sl<ProcessTabPaymentUseCase>();

    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemSelectionSheet(
        items: items,
        balance: session.balance,
        subtitle: session.displayLabel(),
        onPay: (req) async {
          final result = await useCase(
            tabSessionId: session.id,
            amount: req.amount,
            paymentMethod: req.method,
            tenantPaymentAccountId: req.tenantAccountId,
            // Sin esto, el backend nunca se entera de QUÉ ítems cubre este
            // pago — el sheet ya arma el JSON con `__items__`, pero antes
            // se descartaba acá. Por eso un ítem pagado no quedaba
            // marcado como "Cobrado" la próxima vez que se abría "Por
            // ítems" en esta cuenta (bug real, preexistente).
            notes: req.notesJson,
            receivedAmount:
                req.method == PaymentMethod.cash ? req.receivedAmount : null,
          );
          return result.fold(
            (failure) {
              if (isCashSessionRequiredError(failure.message)) {
                handleCashSessionError(failure.message);
              } else {
                AppSnackbar.show('Error al cobrar', failure.message);
              }
              return false;
            },
            (_) => true,
          );
        },
      ),
    );

    if (paid == true && mounted) {
      // selectedSubtotal sigue seteado en los objetos (mutados por el sheet)
      final paidAmount = items.fold(0.0, (s, i) => s + i.selectedSubtotal);
      AppSnackbar.show(
        'Cobro exitoso',
        '${CurrencyFormatter.format(paidAmount)} cobrado',
      );
      if (paidAmount >= session.balance - 0.01) {
        PrintingOrchestrator.autoPrintTabSessionReceipt(session);
      }
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final screen = mq.size;
    final kb = mq.viewInsets.bottom;
    final hPad = screen.width < 600 ? 16.0 : 40.0;
    final vPad = screen.height < 700 ? 16.0 : 24.0;
    final maxW = screen.width < 600
        ? screen.width * 0.92
        : (screen.width < 900 ? 480.0 : 500.0);
    final maxH = (screen.height - kb - 2 * vPad).clamp(0.0, 700.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.fromLTRB(hPad, vPad, hPad, vPad + kb),
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
                    _SectionTitle('Monto a cobrar'),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [ThousandsSeparatorInputFormatter()],
                            decoration: _inputDecoration(
                              prefix: '\$ ',
                              hint: '0',
                              helper: _amount > session.balance + 0.01
                                  ? 'Supera el saldo (${CurrencyFormatter.format(session.balance)})'
                                  : (_amount < session.balance - 0.01 && _amount > 0
                                      ? 'Pago parcial — queda '
                                          '${CurrencyFormatter.format(session.balance - _amount)}'
                                      : null),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonal(
                          onPressed: _useFullBalance,
                          child: const Text('Todo'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, safeBottom + 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.checklist_rtl, size: 18),
              label: const Text('Cobrar por ítems'),
              onPressed: _isProcessing ? null : _openItemSelection,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: enabled ? _processPayment : null,
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
                      : (session.paidAmount > 0.01
                          ? 'Cobrar restante ${CurrencyFormatter.format(_amount)}'
                          : 'Procesar pago ${CurrencyFormatter.format(_amount)}')),
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

// ════════════════════════ Piezas compartidas ════════════════════════

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
  const _Header({
    required this.title,
    required this.subtitle,
    required this.onClose,
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
          Icon(Icons.payment, color: theme.colorScheme.onPrimaryContainer, size: 26),
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
    return PaymentMethodSelector(
      selectedMethod: selected,
      onMethodSelected: onSelect,
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

