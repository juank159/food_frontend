import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

import '../../../core/config/formatters/currency_formatter.dart';
import '../../../core/config/formatters/datetime_formatter.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/widgets/sheet_handle.dart';
import '../../../core/widgets/widgets.dart';
import '../../inventory/domain/entities/ingredient.dart';
import '../../inventory/presentation/widgets/inventory_format.dart';
import '../../inventory/presentation/widgets/quantity_unit_field.dart';
import '../../inventory/services/inventory_stock_service.dart';
import '../data/suppliers_models.dart';
import '../data/suppliers_repository.dart';
import 'supplier_sheets.dart';

String purchaseStatusLabel(Purchase p) {
  if (p.isCancelled) return 'Cancelada';
  if (p.isOrder) return 'Orden · por llegar';
  if (p.paymentStatus == 'paid') return 'Pagada';
  if (p.isOverdue) return 'Vencida';
  return p.paymentStatus == 'partial' ? 'Abonada' : 'Por pagar';
}

Color purchaseStatusColor(Purchase p) {
  if (p.isCancelled) return Colors.grey;
  if (p.isOrder) return AppColors.info;
  if (p.paymentStatus == 'paid') return AppColors.success;
  if (p.isOverdue) return AppColors.error;
  return AppColors.warning;
}

/// Detalle de una compra: líneas, saldo y pagos. Acciones: recibir una
/// orden, cancelarla, pagar lo que se debe.
class PurchaseDetailPage extends StatefulWidget {
  const PurchaseDetailPage({super.key});

  @override
  State<PurchaseDetailPage> createState() => _PurchaseDetailPageState();
}

class _PurchaseDetailPageState extends State<PurchaseDetailPage> {
  final _repo = GetIt.instance<SuppliersRepository>();
  late final String _id = Get.parameters['id'] ?? '';
  Purchase? _p;
  bool _loading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final p = await _repo.purchaseDetail(_id);
    if (!mounted) return;
    setState(() {
      _p = p;
      _loading = false;
    });
  }

  Supplier? get _supplier =>
      _repo.readSuppliers().firstWhereOrNull((s) => s.id == _p?.supplierId);

  Future<void> _receive() async {
    final p = _p!;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReceiveSheet(purchase: p),
    );
    if (ok == true) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _cancel() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar la orden?'),
        content: const Text(
          'No llegó y ya no se va a recibir. No mueve stock ni deja deuda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar orden'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    final r = await _repo.cancelPurchase(_id);
    if (r.failed) return AppSnackbar.show('Orden', r.error!);
    _changed = true;
    AppSnackbar.show(
      'Orden',
      r.synced
          ? 'Orden cancelada'
          : 'Guardado sin internet · se sincroniza solo',
    );
    await _load();
  }

  Future<void> _pay() async {
    final s = _supplier;
    if (s == null || _p == null) return;
    if (await showPaySupplierSheet(
      context,
      supplier: s,
      owed: _p!.balance,
      purchase: _p,
    )) {
      _changed = true;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          p == null ? 'Compra' : (p.isOrder ? 'Orden de compra' : 'Compra'),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: BackButton(onPressed: () => Get.back(result: _changed)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : p == null
          ? const Center(child: Text('No se encontró la compra.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _header(p),
                const SizedBox(height: 12),
                _section('Insumos', [for (final l in p.lines) _lineTile(p, l)]),
                if (p.payments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _section('Pagos', [
                    for (final pay in p.payments)
                      ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.payments_outlined,
                          color: AppColors.success,
                        ),
                        title: Text(CurrencyFormatter.format(pay.applied)),
                        subtitle: Text(
                          [
                            PaymentSources.label(pay.paymentSource),
                            if (pay.paidAt != null)
                              DateTimeFormatter.dateOnly(pay.paidAt!),
                            if (pay.amount > pay.applied + 0.5)
                              'de un pago de ${CurrencyFormatter.format(pay.amount)}',
                          ].join(' · '),
                        ),
                      ),
                  ]),
                ],
                if (p.notes != null && p.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _section('Nota', [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(p.notes!),
                    ),
                  ]),
                ],
              ],
            ),
      bottomNavigationBar: p == null || p.pendingSync ? null : _actions(p),
    );
  }

  Widget? _actions(Purchase p) {
    if (p.isOrder) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancel,
                  child: const Text('Cancelar orden'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _receive,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Recibir mercancía'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (p.isReceived && p.balance > 0.004 && _supplier != null) {
      return AppPrimaryActionBar(
        label: 'Pagar ${CurrencyFormatter.format(p.balance)}',
        icon: Icons.payments_outlined,
        onPressed: _pay,
      );
    }
    return null;
  }

  Widget _header(Purchase p) {
    final color = purchaseStatusColor(p);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.supplierName ?? 'Sin proveedor',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  purchaseStatusLabel(p),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (p.pendingSync)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Pendiente de sincronizar',
                style: TextStyle(color: AppColors.warning),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            [
              if (p.invoiceNumber != null) 'Factura ${p.invoiceNumber}',
              if (p.orderedAt != null)
                'Pedida ${DateTimeFormatter.dateOnly(p.orderedAt!)}',
              if (p.receivedAt != null)
                'Recibida ${DateTimeFormatter.dateOnly(p.receivedAt!)}',
              if (p.isReceived && p.dueDate != null && p.balance > 0)
                'Vence ${DateTimeFormatter.dateOnly(p.dueDate!)}',
            ].join(' · '),
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const Divider(height: 20),
          _kv('Total', CurrencyFormatter.format(p.total), bold: true),
          if (p.isReceived) ...[
            _kv('Pagado', CurrencyFormatter.format(p.paidAmount)),
            _kv(
              'Se debe',
              CurrencyFormatter.format(p.balance),
              color: p.balance > 0 ? AppColors.error : AppColors.success,
              bold: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: Text(k)),
        Text(
          v,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    ),
  );

  Widget _section(String title, List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        ...children,
      ],
    ),
  );

  Widget _lineTile(Purchase p, PurchaseLine l) {
    final ing = InventoryStockService.maybe?.byId(l.ingredientId);
    final unit = ing?.unit ?? IngredientUnit.fromCode(l.unit);
    final name = l.ingredientName ?? ing?.name ?? 'Insumo';
    final qty = l.quantityReceived ?? l.quantityOrdered;
    final differs =
        l.quantityReceived != null &&
        (l.quantityReceived! - l.quantityOrdered).abs() > 0.0005;
    return ListTile(
      dense: true,
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        [
          fmtQty(qty, unit),
          if (differs) 'pedido ${fmtQty(l.quantityOrdered, unit)}',
          if (l.unitCost != null)
            unitCostLabel(CurrencyFormatter.format(l.unitCost!), unit),
        ].join(' · '),
      ),
      trailing: Text(
        CurrencyFormatter.format(l.lineTotal),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Recibir una orden: cantidades y costos reales de lo que llegó.
class _ReceiveSheet extends StatefulWidget {
  final Purchase purchase;
  const _ReceiveSheet({required this.purchase});

  @override
  State<_ReceiveSheet> createState() => _ReceiveSheetState();
}

class _ReceiveSheetState extends State<_ReceiveSheet> {
  late final Map<String, double?> _qty = {
    for (final l in widget.purchase.lines) l.id: l.quantityOrdered,
  };
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final r = await GetIt.instance<SuppliersRepository>().receivePurchase(
      widget.purchase.id,
      {
        'lines': [
          for (final l in widget.purchase.lines)
            {
              'line_id': l.id,
              'quantity_received': _qty[l.id] ?? 0,
              if (l.unitCost != null) 'unit_cost': l.unitCost,
            },
        ],
      },
    );
    InventoryStockService.maybe?.reloadLocal();
    if (!mounted) return;
    setState(() => _saving = false);
    if (r.failed) {
      AppSnackbar.show('Recibir', r.error!);
      return;
    }
    AppSnackbar.show(
      'Mercancía recibida',
      r.synced
          ? 'Stock actualizado'
          : 'Guardado sin internet · se sincroniza solo',
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const Text(
              '¿Qué llegó?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Corregí si llegó otra cantidad. Suma al stock de la sede de la orden.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            for (final l in widget.purchase.lines) ...[
              Text(
                l.ingredientName ??
                    InventoryStockService.maybe?.byId(l.ingredientId)?.name ??
                    'Insumo',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              QuantityUnitField(
                baseUnit:
                    InventoryStockService.maybe?.byId(l.ingredientId)?.unit ??
                    IngredientUnit.fromCode(l.unit),
                initialBaseValue: l.quantityOrdered,
                label: 'Cantidad que llegó',
                onChanged: (v) => _qty[l.id] = v,
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Guardando…' : 'Confirmar recepción'),
            ),
          ],
        ),
      ),
    );
  }
}
