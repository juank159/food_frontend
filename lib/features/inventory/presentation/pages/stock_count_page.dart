import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/inventory_repository.dart';
import '../../domain/entities/ingredient.dart';
import '../../services/inventory_stock_service.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/inventory_format.dart';
import '../widgets/quantity_unit_field.dart';

/// Conteo físico: se cuenta lo que hay de verdad y el sistema ajusta la
/// diferencia (faltante/sobrante). Así se detectan pérdidas, robos o
/// recetas mal cargadas.
///
/// Se manda `esperado` = lo que el sistema mostraba AL CONTAR (no "dejar
/// en lo contado"): un conteo hecho sin internet y sincronizado después
/// no pisa las ventas que entraron mientras tanto.
class StockCountPage extends StatefulWidget {
  const StockCountPage({super.key});

  @override
  State<StockCountPage> createState() => _StockCountPageState();
}

class _StockCountPageState extends State<StockCountPage> {
  final _repo = GetIt.instance<InventoryRepository>();
  final _stock = Get.find<InventoryStockService>();

  /// id → (contado, esperado al momento de escribirlo).
  final Map<String, ({double counted, double expected})> _counts = {};
  String? _category;
  String _q = '';
  bool _saving = false;

  List<String> get _categories {
    final set = <String>{};
    for (final i in _stock.ingredients) {
      if (i.category != null && i.category!.trim().isNotEmpty) set.add(i.category!.trim());
    }
    return set.toList()..sort();
  }

  List<Ingredient> get _visible => _stock.ingredients
      .where((i) => i.isActive)
      .where((i) => _category == null || i.category == _category)
      .where((i) => _q.isEmpty || i.name.toLowerCase().contains(_q.toLowerCase()))
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  double get _valueDiff {
    var total = 0.0;
    _counts.forEach((id, c) {
      total += (c.counted - c.expected) * (_stock.byId(id)?.avgCost ?? 0);
    });
    return total;
  }

  Future<void> _submit() async {
    if (_counts.isEmpty) {
      AppSnackbar.show('Nada contado', 'Escribí lo que contaste en al menos un insumo.');
      return;
    }
    final diffs = _counts.values.where((c) => (c.counted - c.expected).abs() > 1e-9).length;
    final ok = await confirmInventoryAction(
      context,
      title: 'Guardar conteo',
      message: 'Contaste ${_counts.length} insumo${_counts.length == 1 ? '' : 's'}; '
          '$diffs con diferencia. El stock se ajusta a lo contado.',
      confirmText: 'Guardar',
    );
    if (!ok) return;
    setState(() => _saving = true);
    final r = await _repo.count(
      lines: [
        for (final e in _counts.entries)
          (ingredientId: e.key, counted: e.value.counted, expected: e.value.expected),
      ],
    );
    _stock.reloadLocal();
    if (!mounted) return;
    setState(() => _saving = false);
    r.fold(
      (f) => AppSnackbar.show('No se pudo guardar', f.message),
      (res) {
        AppSnackbar.show(
          'Conteo guardado',
          res.synced ? 'Stock ajustado' : 'Guardado sin internet · se sincroniza solo',
        );
        Get.back();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const AppGradientHeader(
              title: 'Conteo físico',
              subtitle: 'Contá lo que hay y escribilo: el sistema ajusta la diferencia',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar insumo…',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            if (_categories.isNotEmpty)
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    AppFilterChip(
                      label: 'Todos',
                      selected: _category == null,
                      onTap: () => setState(() => _category = null),
                    ),
                    for (final c in _categories)
                      AppFilterChip(
                        label: c,
                        selected: _category == c,
                        onTap: () => setState(() => _category = c),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: Obx(() {
                final _ = _stock.ingredients.length;
                final list = _visible;
                if (list.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'Sin insumos',
                    message: 'Creá tus insumos desde Inventario para poder contarlos.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _countRow(list[i]),
                );
              }),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: AppColors.cardBackground,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${_counts.length} contados',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (_counts.isNotEmpty)
                            Text(
                              _valueDiff == 0
                                  ? 'Sin diferencia de valor'
                                  : '${_valueDiff < 0 ? 'Faltante' : 'Sobrante'}: '
                                      '${CurrencyFormatter.format(_valueDiff.abs())}',
                              style: TextStyle(
                                fontSize: 12,
                                color: _valueDiff < 0 ? AppColors.error : AppColors.success,
                              ),
                            ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: const Icon(Icons.check),
                      label: const Text('Guardar conteo'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countRow(Ingredient ing) {
    final c = _counts[ing.id];
    final diff = c == null ? null : c.counted - c.expected;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: diff == null || diff.abs() < 1e-9
              ? AppColors.border
              : (diff < 0 ? AppColors.error : AppColors.success).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(ing.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              Text('Sistema: ${fmtQty(c?.expected ?? ing.currentStock, ing.unit)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          QuantityUnitField(
            baseUnit: ing.unit,
            label: 'Contado',
            onChanged: (v) => setState(() {
              if (v == null) {
                _counts.remove(ing.id);
              } else {
                _counts[ing.id] = (
                  counted: v,
                  // Fijamos el "esperado" la primera vez que se escribe,
                  // aunque después entre una venta (ver doc de la clase).
                  expected: _counts[ing.id]?.expected ?? ing.currentStock,
                );
              }
            }),
          ),
          if (diff != null && diff.abs() > 1e-9)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${diff < 0 ? 'Faltan' : 'Sobran'} ${fmtQty(diff.abs(), ing.unit)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: diff < 0 ? AppColors.error : AppColors.success,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
