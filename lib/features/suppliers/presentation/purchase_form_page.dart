import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

import '../../../core/config/formatters/currency_formatter.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/input_formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../inventory/domain/entities/ingredient.dart';
import '../../inventory/presentation/widgets/ingredient_form_sheet.dart';
import '../../inventory/presentation/widgets/inventory_format.dart';
import '../../inventory/presentation/widgets/quantity_unit_field.dart';
import '../../inventory/services/inventory_stock_service.dart';
import '../data/suppliers_models.dart';
import '../data/suppliers_repository.dart';
import 'supplier_sheets.dart';

class _Line {
  final Ingredient ingredient;
  double? quantity;
  int? totalPaid;
  final TextEditingController paidCtrl = TextEditingController();
  _Line(this.ingredient, {this.quantity});
}

/// Registrar una compra (llegó la mercancía: suma stock) o una orden de
/// compra (pedida, todavía no llega). Funciona sin internet.
///
/// Argumentos opcionales: `{'supplierId', 'asOrder', 'lines': [{ingredientId, quantity}]}`
/// (las compras sugeridas abren esta pantalla ya armada).
class PurchaseFormPage extends StatefulWidget {
  const PurchaseFormPage({super.key});

  @override
  State<PurchaseFormPage> createState() => _PurchaseFormPageState();
}

class _PurchaseFormPageState extends State<PurchaseFormPage> {
  final _repo = GetIt.instance<SuppliersRepository>();
  final _stock = Get.find<InventoryStockService>();
  final List<_Line> _lines = [];
  final _invoice = TextEditingController();
  final _notes = TextEditingController();
  List<Supplier> _suppliers = [];
  String? _supplierId;
  bool _asOrder = false;
  bool _paidNow = false;
  String _source = 'cash_register';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _suppliers = _repo.readSuppliers().where((s) => s.isActive).toList();
    final args = (Get.arguments as Map?) ?? const {};
    _supplierId = args['supplierId'] as String?;
    _asOrder = args['asOrder'] as bool? ?? false;
    for (final l in (args['lines'] as List? ?? const []).whereType<Map>()) {
      final ing = _stock.byId(l['ingredientId'] as String);
      if (ing != null) {
        _lines.add(_Line(ing, quantity: (l['quantity'] as num?)?.toDouble()));
      }
    }
  }

  @override
  void dispose() {
    _invoice.dispose();
    _notes.dispose();
    for (final l in _lines) {
      l.paidCtrl.dispose();
    }
    super.dispose();
  }

  Supplier? get _supplier =>
      _suppliers.firstWhereOrNull((s) => s.id == _supplierId);
  int get _total => _lines.fold(0, (s, l) => s + (l.totalPaid ?? 0));

  Future<void> _newSupplier() async {
    final before = _suppliers.map((s) => s.id).toSet();
    if (!await showSupplierForm(context)) return;
    setState(() {
      _suppliers = _repo.readSuppliers().where((s) => s.isActive).toList();
      _supplierId =
          _suppliers.firstWhereOrNull((s) => !before.contains(s.id))?.id ??
          _supplierId;
    });
  }

  Future<void> _addLine() async {
    final ing = await showIngredientPicker(
      context,
      exclude: _lines.map((l) => l.ingredient.id).toSet(),
    );
    if (ing != null) setState(() => _lines.add(_Line(ing)));
  }

  Future<void> _submit() async {
    final valid = _lines.where((l) => (l.quantity ?? 0) > 0).toList();
    if (valid.isEmpty) {
      AppSnackbar.show(
        'Falta la cantidad',
        'Agregá al menos un insumo con su cantidad.',
      );
      return;
    }
    if (_paidNow && _supplierId == null) {
      AppSnackbar.show(
        'Falta el proveedor',
        'Para registrar el pago elegí el proveedor.',
      );
      return;
    }
    setState(() => _saving = true);
    final body = <String, dynamic>{
      if (_supplierId != null) 'supplier_id': _supplierId,
      'status': _asOrder ? 'ordered' : 'received',
      if (_invoice.text.trim().isNotEmpty)
        'invoice_number': _invoice.text.trim(),
      if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      'lines': [
        for (final l in valid)
          {
            'ingredient_id': l.ingredient.id,
            'quantity': l.quantity,
            if (l.totalPaid != null && l.totalPaid! > 0)
              'total_cost': l.totalPaid,
          },
      ],
      if (_paidNow && !_asOrder && _total > 0)
        'payment': {'amount': _total, 'payment_source': _source},
    };
    final r = await _repo.createPurchase(body);
    _stock.reloadLocal();
    if (!mounted) return;
    setState(() => _saving = false);
    if (r.failed) {
      AppSnackbar.show('No se pudo registrar', r.error!);
      return;
    }
    AppSnackbar.show(
      _asOrder ? 'Orden de compra creada' : 'Compra registrada',
      r.synced
          ? (_asOrder
                ? 'Cuando llegue, tocá "Recibir" en la orden.'
                : 'Stock actualizado')
          : 'Guardado sin internet · se sincroniza solo',
    );
    Get.back(result: true);
  }

  @override
  Widget build(BuildContext context) {
    final supplier = _supplier;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppGradientHeader(
              title: _asOrder ? 'Nueva orden de compra' : 'Registrar compra',
              subtitle: _asOrder
                  ? 'Lo que le pedís al proveedor. No suma stock hasta que llegue.'
                  : 'Llegó la mercancía: suma al stock de esta sede y actualiza costos.',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Ya llegó'),
                        icon: Icon(Icons.inventory_2_outlined),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Orden (por llegar)'),
                        icon: Icon(Icons.schedule),
                      ),
                    ],
                    selected: {_asOrder},
                    onSelectionChanged: (s) =>
                        setState(() => _asOrder = s.first),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _supplierId,
                          isExpanded: true,
                          decoration: _dec(
                            'Proveedor',
                            Icons.local_shipping_outlined,
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Sin proveedor'),
                            ),
                            for (final s in _suppliers)
                              DropdownMenuItem<String?>(
                                value: s.id,
                                child: Text(
                                  s.pendingSync
                                      ? '${s.name} (sin sincronizar)'
                                      : s.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() => _supplierId = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Nuevo proveedor',
                        onPressed: _newSupplier,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  if (supplier != null &&
                      supplier.paymentTermsDays > 0 &&
                      !_asOrder)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        'Crédito de ${supplier.paymentTermsDays} días: vence el '
                        '${_dueLabel(supplier.paymentTermsDays)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _invoice,
                    decoration: _dec(
                      'N.º de factura (opcional)',
                      Icons.receipt_long_outlined,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < _lines.length; i++) _lineCard(i),
                  OutlinedButton.icon(
                    onPressed: _addLine,
                    icon: const Icon(Icons.add),
                    label: Text(
                      _lines.isEmpty ? 'Elegir insumo' : 'Agregar otro insumo',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notes,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _dec('Nota (opcional)', Icons.notes_outlined),
                  ),
                  if (_total > 0) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Total: ${CurrencyFormatter.format(_total)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if (!_asOrder && _total > 0) ...[
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _paidNow,
                      onChanged: (v) => setState(() => _paidNow = v ?? false),
                      title: const Text('Ya la pagué (de contado)'),
                      subtitle: const Text(
                        'Si no, queda en "Por pagar" al proveedor',
                      ),
                    ),
                    if (_paidNow)
                      DropdownButtonFormField<String>(
                        initialValue: _source,
                        decoration: _dec(
                          '¿Con qué plata?',
                          Icons.payments_outlined,
                        ),
                        items: [
                          for (final e in PaymentSources.all.entries)
                            DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                        ],
                        onChanged: (v) =>
                            setState(() => _source = v ?? 'cash_register'),
                      ),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: Icon(
                      _asOrder
                          ? Icons.schedule_send
                          : Icons.local_shipping_outlined,
                    ),
                    label: Text(
                      _saving
                          ? 'Guardando…'
                          : (_asOrder
                                ? 'Crear orden de compra'
                                : 'Registrar compra'),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dueLabel(int days) {
    final d = DateTime.now().add(Duration(days: days));
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Widget _lineCard(int i) {
    final l = _lines[i];
    final ing = _stock.byId(l.ingredient.id) ?? l.ingredient;
    final q = l.quantity ?? 0;
    final unitCost = l.totalPaid != null && q > 0 ? l.totalPaid! / q : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ing.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Hay ${fmtQty(ing.currentStock, ing.unit)} en esta sede',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () =>
                    setState(() => _lines.removeAt(i).paidCtrl.dispose()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: QuantityUnitField(
              baseUnit: ing.unit,
              initialBaseValue: l.quantity,
              label: _asOrder ? 'Cantidad a pedir' : 'Cantidad que llegó',
              onChanged: (v) => setState(() => l.quantity = v),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextField(
              controller: l.paidCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: InputDecoration(
                labelText: _asOrder
                    ? 'Valor acordado (opcional)'
                    : 'Total pagado por esto',
                prefixText: '\$ ',
                isDense: true,
                helperText: unitCost != null
                    ? 'Sale a ${CurrencyFormatter.format(unitCost)} por ${ing.unit.short}'
                    : ing.lastCost != null
                    ? 'Última compra: ${CurrencyFormatter.format(ing.lastCost!)} por ${ing.unit.short}'
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(
                () => l.totalPaid = NumberFormatHelper.parseFormattedInt(v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );
}
