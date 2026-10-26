import 'package:flutter/material.dart';
import '../../../../core/services/branch/branch_service.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/input_formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/inventory_repository.dart';
import '../../domain/entities/ingredient.dart';
import '../../services/inventory_stock_service.dart';
import '../widgets/ingredient_form_sheet.dart';
import '../widgets/inventory_format.dart';
import '../widgets/quantity_unit_field.dart';

enum StockOperationMode {
  purchase('Registrar compra', 'Entrada de mercancía: suma stock y actualiza el costo.',
      Icons.local_shipping_outlined),
  waste('Registrar merma', 'Lo que se dañó, se quemó o venció: resta stock.',
      Icons.delete_sweep_outlined),
  adjust('Ajustar stock', 'Corrección manual con una nota de por qué.', Icons.tune),
  transfer('Trasladar a otra sede', 'Sale del stock de esta sede y entra al de la otra.',
      Icons.swap_horiz);

  final String title;
  final String subtitle;
  final IconData icon;
  const StockOperationMode(this.title, this.subtitle, this.icon);
}

const _wasteReasons = ['Se dañó', 'Se quemó', 'Vencido', 'Se cayó', 'Consumo interno', 'Otro'];

class _Line {
  Ingredient ingredient;
  double? quantity;
  int? totalPaid; // compra: lo que se pagó por esta línea
  String reason = _wasteReasons.first;
  final TextEditingController paidCtrl = TextEditingController();
  _Line(this.ingredient);
}

/// Compra / merma / ajuste. Funciona sin internet: queda en la cola y
/// el stock se ve actualizado al instante.
class StockOperationPage extends StatefulWidget {
  const StockOperationPage({super.key});

  @override
  State<StockOperationPage> createState() => _StockOperationPageState();
}

class _StockOperationPageState extends State<StockOperationPage> {
  final _repo = GetIt.instance<InventoryRepository>();
  final _stock = Get.find<InventoryStockService>();
  late final StockOperationMode _mode;
  final List<_Line> _lines = [];
  final _supplier = TextEditingController();
  final _invoice = TextEditingController();
  final _notes = TextEditingController();
  bool _subtract = false; // ajuste: sumar o restar
  bool _saving = false;
  BranchInfo? _toBranch; // traslado: sede destino

  @override
  void initState() {
    super.initState();
    final args = (Get.arguments as Map?) ?? const {};
    _mode = args['mode'] as StockOperationMode? ?? StockOperationMode.purchase;
    final id = args['ingredientId'] as String?;
    final ing = id == null ? null : _stock.byId(id);
    if (ing != null) _lines.add(_Line(ing));
  }

  @override
  void dispose() {
    _supplier.dispose();
    _invoice.dispose();
    _notes.dispose();
    for (final l in _lines) {
      l.paidCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _addLine() async {
    final ing = await showIngredientPicker(
      context,
      exclude: _lines.map((l) => l.ingredient.id).toSet(),
    );
    if (ing != null) setState(() => _lines.add(_Line(ing)));
  }

  int get _totalPaid => _lines.fold(0, (s, l) => s + (l.totalPaid ?? 0));

  Future<void> _submit() async {
    final valid = _lines.where((l) => (l.quantity ?? 0) > 0).toList();
    if (valid.isEmpty) {
      AppSnackbar.show('Falta la cantidad', 'Agregá al menos un insumo con su cantidad.');
      return;
    }
    final fromBranch = BranchService.maybe?.current.value;
    if (_mode == StockOperationMode.transfer && (fromBranch == null || _toBranch == null)) {
      AppSnackbar.show('Falta la sede', 'Elegí a qué sede va la mercancía.');
      return;
    }
    if (_mode == StockOperationMode.adjust && _notes.text.trim().isEmpty) {
      AppSnackbar.show('Falta el motivo', 'Contá por qué ajustás (ej. "se contó mal ayer").');
      return;
    }
    setState(() => _saving = true);
    final result = switch (_mode) {
      StockOperationMode.purchase => await _repo.purchase(
          supplier: _supplier.text,
          invoiceNumber: _invoice.text,
          notes: _notes.text,
          lines: [
            for (final l in valid)
              (
                ingredientId: l.ingredient.id,
                quantity: l.quantity!,
                unitCost: l.totalPaid != null && l.totalPaid! > 0
                    ? l.totalPaid! / l.quantity!
                    : null,
              ),
          ],
        ),
      StockOperationMode.waste => await _repo.waste(
          notes: _notes.text,
          lines: [
            for (final l in valid)
              (ingredientId: l.ingredient.id, quantity: l.quantity!, reason: l.reason),
          ],
        ),
      StockOperationMode.adjust => await _repo.adjust(
          ingredientId: valid.first.ingredient.id,
          delta: _subtract ? -valid.first.quantity! : valid.first.quantity!,
          notes: _notes.text,
        ),
      StockOperationMode.transfer => await _repo.transfer(
          fromBranchId: fromBranch!.id,
          toBranchId: _toBranch!.id,
          notes: _notes.text,
          lines: [
            for (final l in valid) (ingredientId: l.ingredient.id, quantity: l.quantity!),
          ],
        ),
    };
    _stock.reloadLocal();
    if (!mounted) return;
    setState(() => _saving = false);
    result.fold(
      (f) => AppSnackbar.show('No se pudo registrar', f.message),
      (r) {
        AppSnackbar.show(
          switch (_mode) {
            StockOperationMode.purchase => 'Compra registrada',
            StockOperationMode.waste => 'Merma registrada',
            StockOperationMode.adjust => 'Ajuste registrado',
            StockOperationMode.transfer => 'Traslado a ${_toBranch?.name ?? 'otra sede'}',
          },
          r.synced ? 'Stock actualizado' : 'Guardado sin internet · se sincroniza solo',
        );
        Get.back();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdjust = _mode == StockOperationMode.adjust;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppGradientHeader(title: _mode.title, subtitle: _mode.subtitle),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_mode == StockOperationMode.purchase) ...[
                    TextField(
                      controller: _supplier,
                      textCapitalization: TextCapitalization.words,
                      decoration: _dec('Proveedor (opcional)', Icons.storefront_outlined),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _invoice,
                      decoration: _dec('N.º de factura (opcional)', Icons.receipt_long_outlined),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_mode == StockOperationMode.transfer) ...[
                    _transferBranches(),
                    const SizedBox(height: 16),
                  ],
                  if (isAdjust && _lines.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Sumar'), icon: Icon(Icons.add)),
                          ButtonSegment(value: true, label: Text('Restar'), icon: Icon(Icons.remove)),
                        ],
                        selected: {_subtract},
                        onSelectionChanged: (s) => setState(() => _subtract = s.first),
                      ),
                    ),
                  for (var i = 0; i < _lines.length; i++) _lineCard(i),
                  if (!isAdjust || _lines.isEmpty)
                    OutlinedButton.icon(
                      onPressed: _addLine,
                      icon: const Icon(Icons.add),
                      label: Text(_lines.isEmpty ? 'Elegir insumo' : 'Agregar otro insumo'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notes,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _dec(isAdjust ? 'Motivo del ajuste *' : 'Nota (opcional)',
                        Icons.notes_outlined),
                  ),
                  if (_mode == StockOperationMode.purchase && _totalPaid > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Total de la compra: ${CurrencyFormatter.format(_totalPaid)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
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
                    icon: Icon(_mode.icon),
                    label: Text(_mode.title),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          _mode == StockOperationMode.waste ? AppColors.error : AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _lineCard(int i) {
    final l = _lines[i];
    final ing = _stock.byId(l.ingredient.id) ?? l.ingredient;
    final q = l.quantity ?? 0;
    final after = _mode == StockOperationMode.purchase
        ? ing.currentStock + q
        : _mode == StockOperationMode.waste ||
                _mode == StockOperationMode.transfer ||
                _subtract
            ? ing.currentStock - q
            : ing.currentStock + q;
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
                    Text(ing.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                      'Hay ${fmtQty(ing.currentStock, ing.unit)}'
                      '${q > 0 ? ' → quedan ${fmtQty(after, ing.unit)}' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: after < 0 ? AppColors.error : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _lines.removeAt(i).paidCtrl.dispose()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: QuantityUnitField(
              baseUnit: ing.unit,
              autofocus: true,
              label: _mode == StockOperationMode.purchase ? 'Cantidad que llegó' : 'Cantidad',
              onChanged: (v) => setState(() => l.quantity = v),
            ),
          ),
          if (_mode == StockOperationMode.purchase) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextField(
                controller: l.paidCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Total pagado por esto (opcional)',
                  prefixText: '\$ ',
                  isDense: true,
                  helperText: unitCost != null
                      ? 'Sale a ${CurrencyFormatter.format(unitCost)} por ${ing.unit.short}'
                      : ing.lastCost != null
                          ? 'Última compra: ${CurrencyFormatter.format(ing.lastCost!)} por ${ing.unit.short}'
                          : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) =>
                    setState(() => l.totalPaid = NumberFormatHelper.parseFormattedInt(v)),
              ),
            ),
          ],
          if (_mode == StockOperationMode.waste) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in _wasteReasons)
                  ChoiceChip(
                    label: Text(r),
                    selected: l.reason == r,
                    onSelected: (_) => setState(() => l.reason = r),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _transferBranches() {
    final service = BranchService.maybe;
    final from = service?.current.value;
    final targets = (service?.mine ?? const <BranchInfo>[])
        .where((b) => b.id != from?.id)
        .toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sale de: ${from?.name ?? '—'} (este dispositivo)',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _toBranch?.id,
            decoration: _dec('Va para', Icons.storefront_outlined),
            items: [
              for (final b in targets) DropdownMenuItem(value: b.id, child: Text(b.name)),
            ],
            onChanged: (id) => setState(
              () => _toBranch = targets.firstWhereOrNull((b) => b.id == id),
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
