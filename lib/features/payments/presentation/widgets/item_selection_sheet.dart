import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/input_formatters.dart';
import '../../../cash_sessions/presentation/widgets/cash_session_required_banner.dart';
import '../../../tenant_payment_accounts/domain/entities/tenant_payment_account.dart';
import '../../../tenant_payment_accounts/domain/usecases/tenant_payment_account_usecases.dart';
import 'payment_method_selector.dart';

/// Un ítem a mostrar en el sheet de cobro por ítems.
///
/// [paidQty] refleja cuántos ya fueron cobrados (calculado antes de abrir
/// el sheet). Si no hay información de cobros anteriores, pasa 0.
class SelectableItemEntry {
  final String itemId;

  /// Si no es null, el sheet muestra un encabezado de agrupación con este
  /// valor (útil para cuentas abiertas con varios tickets).
  final String? orderLabel;

  final String name;
  final String? variantName;
  final double unitPrice;
  final int totalQty;
  final int paidQty;
  int selectedQty;

  SelectableItemEntry({
    required this.itemId,
    this.orderLabel,
    required this.name,
    this.variantName,
    required this.unitPrice,
    required this.totalQty,
    this.paidQty = 0,
  }) : selectedQty = 0;

  int get remainingQty => (totalQty - paidQty).clamp(0, totalQty);
  bool get isFullyPaid => paidQty >= totalQty;
  bool get isPartiallyPaid => paidQty > 0 && !isFullyPaid;
  bool get isSelectable => remainingQty > 0;
  double get selectedSubtotal => unitPrice * selectedQty;
}

/// Datos que el sheet pasa al callback [ItemSelectionSheet.onPay].
class ItemPayRequest {
  final double amount;

  /// JSON con `{"__items__": [{"id": ..., "qty": ...}]}` para rastrear
  /// qué ítems específicos cubre este pago.
  final String? notesJson;
  final PaymentMethod method;
  final String? tenantAccountId;
  final double? receivedAmount;

  const ItemPayRequest({
    required this.amount,
    this.notesJson,
    required this.method,
    this.tenantAccountId,
    this.receivedAmount,
  });
}

/// Sheet unificado de "cobrar por ítems".
///
/// Muestra TODOS los ítems:
/// - Pagados: tachados en verde con badge "Cobrado" (no seleccionables).
/// - Parcialmente pagados: badge "N/M pagado" y stepper para el restante.
/// - Pendientes: stepper normal.
///
/// Incluye selector de método de pago + campo de recibido para efectivo.
/// Llama a [onPay] al confirmar; retorna `true` si tuvo éxito y hace pop.
class ItemSelectionSheet extends StatefulWidget {
  final List<SelectableItemEntry> items;

  /// Monto máximo cobrable en este pase (saldo de la orden/cuenta).
  final double balance;

  /// Subtítulo opcional bajo el título (p.ej. etiqueta de la cuenta).
  final String? subtitle;

  /// Callback que ejecuta el cobro. Debe devolver `true` en éxito.
  /// El caller es responsable de mostrar snackbars y manejar errores.
  final Future<bool> Function(ItemPayRequest req) onPay;

  const ItemSelectionSheet({
    super.key,
    required this.items,
    required this.balance,
    this.subtitle,
    required this.onPay,
  });

  @override
  State<ItemSelectionSheet> createState() => _ItemSelectionSheetState();
}

class _ItemSelectionSheetState extends State<ItemSelectionSheet> {
  PaymentMethod _method = PaymentMethod.cash;
  TenantPaymentAccount? _account;
  List<TenantPaymentAccount> _allAccounts = const [];
  final _cashCtrl = TextEditingController();
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _cashCtrl.addListener(_rebuild);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAccounts());
  }

  @override
  void dispose() {
    _cashCtrl.removeListener(_rebuild);
    _cashCtrl.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAccounts() async {
    final useCases = sl<TenantPaymentAccountUseCases>();
    final result = await useCases.getAll(onlyActive: true);
    result.fold((_) {}, (list) {
      if (mounted) setState(() => _allAccounts = list);
    });
  }

  List<TenantPaymentAccount> get _accountsForMethod => _allAccounts
      .where((a) => a.category == _method && a.isActive)
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  double get _total =>
      widget.items.fold(0.0, (s, i) => s + i.selectedSubtotal);

  double get _parsedReceived =>
      (NumberFormatHelper.parseFormattedInt(_cashCtrl.text) ?? 0).toDouble();

  // 0 = no ingresado (opcional); solo bloquea si ingresó un monto insuficiente
  bool get _cashReady =>
      _method != PaymentMethod.cash ||
      _parsedReceived == 0 ||
      _parsedReceived >= _total;

  bool get _canPay =>
      _total > 0.01 && _total <= widget.balance + 0.01 && _cashReady;

  Future<void> _confirm() async {
    if (!_canPay || _processing) return;
    final total = _total;

    final notesJson = jsonEncode({
      '__items__': widget.items
          .where((i) => i.selectedQty > 0)
          .map((i) => {'id': i.itemId, 'qty': i.selectedQty})
          .toList(),
    });

    final req = ItemPayRequest(
      amount: total,
      notesJson: notesJson,
      method: _method,
      tenantAccountId: _account?.id,
      receivedAmount: _method == PaymentMethod.cash ? _parsedReceived : null,
    );

    setState(() => _processing = true);
    final success = await widget.onPay(req);
    if (!mounted) return;
    setState(() => _processing = false);
    if (success) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final kb = mq.viewInsets.bottom;
    final safeBottom = mq.viewPadding.bottom;
    final isSmall = mq.size.height < 700;
    final vPad = isSmall ? 8.0 : 12.0;

    // Agrupar por orderLabel (null = sin encabezado)
    final groups = <String?, List<SelectableItemEntry>>{};
    for (final item in widget.items) {
      (groups[item.orderLabel] ??= []).add(item);
    }

    final selectable = widget.items.where((i) => i.isSelectable).toList();
    final allFull =
        selectable.isNotEmpty && selectable.every((i) => i.selectedQty == i.remainingQty);
    final hasPaid = widget.items.any((i) => i.paidQty > 0);

    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.92 - kb),
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
          // Encabezado
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 8, isSmall ? 4 : 8),
            child: Row(
              children: [
                Icon(Icons.checklist_rtl,
                    color: AppColors.primary, size: isSmall ? 20 : 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cobrar por ítems',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (widget.subtitle != null)
                        Text(
                          widget.subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (selectable.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        for (final i in selectable) {
                          i.selectedQty = allFull ? 0 : i.remainingQty;
                        }
                      });
                    },
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(allFull ? 'Quitar todos' : 'Todos',
                        style: const TextStyle(fontSize: 12)),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Leyenda de ítems pagados
          if (hasPaid)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: Colors.green.shade600, size: 14),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Los ítems en verde ya fueron cobrados',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          // Lista de ítems
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: groups.entries
                  .expand<Widget>((entry) => [
                        if (entry.key != null)
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              entry.key!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurfaceVariant,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ...entry.value.map((item) => _SheetItemTile(
                              item: item,
                              onIncrement: (!item.isFullyPaid &&
                                      item.selectedQty < item.remainingQty)
                                  ? () => setState(() => item.selectedQty++)
                                  : null,
                              onDecrement: item.selectedQty > 0
                                  ? () => setState(() => item.selectedQty--)
                                  : null,
                            )),
                        const Divider(height: 1),
                      ])
                  .toList(),
            ),
          ),
          // Footer
          Padding(
            padding: EdgeInsets.fromLTRB(16, vPad, 16, vPad + safeBottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Método de pago
                PaymentMethodSelector(
                  selectedMethod: _method,
                  onMethodSelected: (m) {
                    setState(() {
                      _method = m;
                      _account = null;
                    });
                  },
                ),
                // Cuentas de cobro
                Builder(builder: (_) {
                  final accounts = _accountsForMethod;
                  if (accounts.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '¿En qué cuenta?',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: accounts.map((acc) {
                            final isSel = _account?.id == acc.id;
                            return GestureDetector(
                              onTap: () => setState(
                                  () => _account = isSel ? null : acc),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? AppColors.primary
                                      : AppColors.cardBackground,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSel
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                ),
                                child: Text(
                                  acc.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isSel
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                }),
                // Banner caja registradora
                CashSessionRequiredBanner(
                    isCashSelected: _method == PaymentMethod.cash),
                // Campo recibido (solo en efectivo)
                if (_method == PaymentMethod.cash && _total > 0.01)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextField(
                      controller: _cashCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsSeparatorInputFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Recibido del cliente (opcional)',
                        prefixText: '\$ ',
                        hintText:
                            NumberFormatHelper.formatNumber(_total.toInt()),
                        prefixIcon: const Icon(Icons.payments_outlined),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                SizedBox(height: vPad),
                // Total
                Builder(builder: (_) {
                  final total = _total;
                  final tooMuch = total > widget.balance + 0.01;
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
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Supera el saldo '
                            '(${CurrencyFormatter.format(widget.balance)})',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
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
                        onPressed:
                            _processing ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44)),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
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
                        onPressed: (_canPay && !_processing) ? _confirm : null,
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 44)),
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

/// Tile de un ítem dentro del sheet.
/// Ítems totalmente pagados se muestran en verde con badge "Cobrado".
/// Ítems parcialmente pagados muestran badge "N/M pagado" y stepper.
/// Ítems pendientes muestran stepper normal.
class _SheetItemTile extends StatelessWidget {
  final SelectableItemEntry item;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  const _SheetItemTile({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fullyPaid = item.isFullyPaid;
    final active = item.selectedQty > 0;

    final nameColor = fullyPaid
        ? Colors.green.shade700
        : active
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurfaceVariant;
    final amtColor = fullyPaid
        ? Colors.green.shade600
        : active
            ? AppColors.primary
            : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          // Ícono check para ítems pagados
          if (fullyPaid)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.check_circle,
                  color: Colors.green.shade600, size: 20),
            ),
          // Info del producto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: nameColor,
                    decoration: fullyPaid ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.green.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.variantName != null)
                  Text(
                    item.variantName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                Text(
                  CurrencyFormatter.format(item.unitPrice),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (item.isPartiallyPaid)
                  Text(
                    '${item.paidQty}/${item.totalQty} pagado',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Badge "Cobrado" para ítems completamente pagados
          if (fullyPaid)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                'Cobrado',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade700,
                ),
              ),
            )
          else ...[
            // Stepper
            _StepBtn(icon: Icons.remove, onTap: onDecrement),
            SizedBox(
              width: 52,
              child: Text(
                '${item.selectedQty}/${item.remainingQty}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: amtColor,
                ),
              ),
            ),
            _StepBtn(icon: Icons.add, onTap: onIncrement),
            const SizedBox(width: 8),
            SizedBox(
              width: 68,
              child: Text(
                CurrencyFormatter.format(item.selectedSubtotal),
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: amtColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepBtn({required this.icon, required this.onTap});

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
