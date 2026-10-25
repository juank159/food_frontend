import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/input_formatters.dart';
import '../../data/inventory_repository.dart';
import '../../domain/entities/ingredient.dart';
import '../../services/inventory_stock_service.dart';
import 'inventory_format.dart';
import 'quantity_unit_field.dart';

/// Alta / edición de un insumo. Devuelve el insumo guardado (o `null`
/// si se canceló). Funciona sin internet: el alta queda con id local y
/// se sincroniza sola.
Future<Ingredient?> showIngredientFormSheet(
  BuildContext context, {
  Ingredient? editing,
  String? suggestedName,
}) {
  return showModalBottomSheet<Ingredient>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _IngredientFormSheet(editing: editing, suggestedName: suggestedName),
  );
}

class _IngredientFormSheet extends StatefulWidget {
  final Ingredient? editing;
  final String? suggestedName;
  const _IngredientFormSheet({this.editing, this.suggestedName});

  @override
  State<_IngredientFormSheet> createState() => _IngredientFormSheetState();
}

class _IngredientFormSheetState extends State<_IngredientFormSheet> {
  final _repo = GetIt.instance<InventoryRepository>();
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _cost;
  late IngredientUnit _unit;
  double? _minStock;
  double? _initialStock;
  bool _saving = false;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _name = TextEditingController(text: e?.name ?? widget.suggestedName ?? '');
    _category = TextEditingController(text: e?.category ?? '');
    _cost = TextEditingController(
      text: e != null && e.avgCost > 0 ? NumberFormatHelper.formatNumber(e.avgCost.round()) : '',
    );
    _unit = e?.unit ?? IngredientUnit.unit;
    _minStock = e?.minStock;
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _cost.dispose();
    super.dispose();
  }

  List<String> get _knownCategories {
    final set = <String>{};
    for (final i in InventoryStockService.maybe?.ingredients ?? const <Ingredient>[]) {
      final c = i.category?.trim();
      if (c != null && c.isNotEmpty) set.add(c);
    }
    return set.toList()..sort();
  }

  /// En edición, al pasar a otra unidad de la MISMA familia (g → kg) se
  /// convierten en pantalla el mínimo y el costo — igual que lo hace el
  /// backend con el stock, las recetas y el historial.
  void _selectUnit(IngredientUnit u) {
    setState(() {
      if (_isEdit && u.family == _unit.family && u != _unit) {
        if (_minStock != null) _minStock = u.convertFrom(_minStock!, _unit);
        final cost = NumberFormatHelper.parseFormattedInt(_cost.text);
        if (cost != null) {
          // costo por unidad: 1 kg cuesta 1000 veces lo que 1 g.
          final converted = cost / u.convertFrom(1, _unit);
          _cost.text = NumberFormatHelper.formatNumber(converted.round());
        }
      }
      _unit = u;
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      AppSnackbar.show('Falta el nombre', 'Ej. "Arepa tipo A", "Queso costeño"');
      return;
    }
    final stock = InventoryStockService.maybe;
    final duplicate = stock?.ingredients.firstWhereOrNull(
      (i) => i.name.toLowerCase() == name.toLowerCase() && i.id != widget.editing?.id,
    );
    if (duplicate != null) {
      AppSnackbar.show('Ya existe', 'Ya tenés un insumo llamado "${duplicate.name}".');
      return;
    }
    final cost = NumberFormatHelper.parseFormattedInt(_cost.text)?.toDouble();
    setState(() => _saving = true);
    Ingredient? result;
    if (_isEdit) {
      final e = widget.editing!;
      final changes = <String, dynamic>{
        if (name != e.name) 'name': name,
        if (_unit != e.unit) 'unit': _unit.code,
        if ((_minStock ?? 0) != e.minStock) 'min_stock': _minStock ?? 0,
        if (_category.text.trim() != (e.category ?? '')) 'category': _category.text.trim(),
        if (cost != null && cost != e.avgCost.roundToDouble()) 'avg_cost': cost,
      };
      if (changes.isNotEmpty) {
        final r = await _repo.updateIngredient(e.id, changes);
        if (r.isLeft()) {
          setState(() => _saving = false);
          r.fold((f) => AppSnackbar.show('No se pudo guardar', f.message), (_) {});
          return;
        }
      }
      stock?.reloadLocal();
      result = stock?.byId(e.id) ?? e;
    } else {
      final r = await _repo.createIngredient(
        name: name,
        unit: _unit,
        minStock: _minStock,
        initialStock: _initialStock,
        unitCost: cost,
        category: _category.text,
      );
      stock?.reloadLocal();
      r.fold(
        (f) => AppSnackbar.show('No se pudo crear', f.message),
        (ing) => result = ing,
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (result != null) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              _isEdit ? 'Editar insumo' : 'Nuevo insumo',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'La materia prima que comprás o preparás (arepa, queso, gaseosa…). '
              'Los productos la descuentan según su receta.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: !_isEdit && (widget.suggestedName ?? '').isEmpty,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Nombre *',
                hintText: 'Ej. Arepa tipo A',
                prefixIcon: const Icon(Icons.inventory_2_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('¿En qué unidad lo llevás?',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final u in IngredientUnit.values)
                  ChoiceChip(
                    label: Text(u.label),
                    selected: _unit == u,
                    onSelected: (_) => _selectUnit(u),
                  ),
              ],
            ),
            if (_isEdit && _unit != widget.editing!.unit)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _unit.family == widget.editing!.unit.family
                      ? 'El stock, el mínimo, los costos, las recetas y el historial '
                          'se convierten solos a ${_unit.label.toLowerCase()}.'
                      : 'De ${widget.editing!.unit.label.toLowerCase()} a '
                          '${_unit.label.toLowerCase()} no hay equivalencia: solo se '
                          'puede si el insumo todavía no tiene stock, recetas ni '
                          'historial. Si no, creá un insumo nuevo.',
                  style: TextStyle(fontSize: 12, color: AppColors.warning),
                ),
              ),
            const SizedBox(height: 14),
            if (!_isEdit) ...[
              QuantityUnitField(
                key: ValueKey('initial_${_unit.code}'),
                baseUnit: _unit,
                label: 'Stock actual (opcional)',
                onChanged: (v) => _initialStock = v,
              ),
              const SizedBox(height: 12),
            ],
            QuantityUnitField(
              key: ValueKey('min_${_unit.code}'),
              baseUnit: _unit,
              initialBaseValue: _minStock,
              label: 'Avisar cuando queden menos de…',
              onChanged: (v) => _minStock = v,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cost,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: InputDecoration(
                labelText: _isEdit
                    ? 'Costo promedio por ${_unit.label.toLowerCase()}'
                    : 'Costo por ${_unit.label.toLowerCase()} (opcional)',
                helperText: 'Para calcular cuánto te cuesta cada plato. '
                    'Se actualiza solo con cada compra.',
                prefixText: '\$ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _category.text),
              optionsBuilder: (v) => _knownCategories
                  .where((c) => c.toLowerCase().contains(v.text.toLowerCase())),
              onSelected: (c) => _category.text = c,
              fieldViewBuilder: (ctx, ctrl, focus, onSubmit) {
                ctrl.addListener(() => _category.text = ctrl.text);
                return TextField(
                  controller: ctrl,
                  focusNode: focus,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Grupo (opcional)',
                    hintText: 'Ej. Panadería, Lácteos, Bebidas',
                    prefixIcon: const Icon(Icons.folder_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check),
                label: Text(_isEdit ? 'Guardar cambios' : 'Crear insumo'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Elegir un insumo (con búsqueda). Incluye "Crear «texto»" para dar de
/// alta uno nuevo sin salir del flujo (ej. armando una receta).
Future<Ingredient?> showIngredientPicker(
  BuildContext context, {
  Set<String> exclude = const {},
  String title = 'Elegí un insumo',
}) {
  return showModalBottomSheet<Ingredient>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _IngredientPicker(exclude: exclude, title: title),
  );
}

class _IngredientPicker extends StatefulWidget {
  final Set<String> exclude;
  final String title;
  const _IngredientPicker({required this.exclude, required this.title});

  @override
  State<_IngredientPicker> createState() => _IngredientPickerState();
}

class _IngredientPickerState extends State<_IngredientPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final stock = InventoryStockService.maybe;
    final all = (stock?.ingredients ?? const <Ingredient>[])
        .where((i) => i.isActive && !widget.exclude.contains(i.id))
        .where((i) => _q.isEmpty || i.name.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    final exact = all.any((i) => i.name.toLowerCase() == _q.trim().toLowerCase());
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Buscar o escribir uno nuevo…',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (v) => setState(() => _q = v),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                if (_q.trim().isNotEmpty && !exact)
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.add, color: Colors.white),
                    ),
                    title: Text('Crear "${_q.trim()}"'),
                    subtitle: const Text('Nuevo insumo'),
                    onTap: () async {
                      final created = await showIngredientFormSheet(
                        context,
                        suggestedName: _q.trim(),
                      );
                      if (created != null && context.mounted) {
                        Navigator.of(context).pop(created);
                      }
                    },
                  ),
                if (_q.trim().isEmpty)
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                    title: const Text('Nuevo insumo'),
                    onTap: () async {
                      final created = await showIngredientFormSheet(context);
                      if (created != null && context.mounted) {
                        Navigator.of(context).pop(created);
                      }
                    },
                  ),
                for (final i in all)
                  ListTile(
                    title: Text(i.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      'Stock: ${fmtQty(i.currentStock, i.unit)}'
                      '${i.category != null && i.category!.isNotEmpty ? ' · ${i.category}' : ''}',
                    ),
                    trailing: Text(i.unit.short,
                        style: const TextStyle(color: AppColors.textSecondary)),
                    onTap: () => Navigator.of(context).pop(i),
                  ),
                if (all.isEmpty && _q.trim().isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Todavía no tenés insumos. Creá el primero arriba.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
