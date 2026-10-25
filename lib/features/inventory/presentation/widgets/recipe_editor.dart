import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../data/inventory_repository.dart';
import '../../domain/entities/ingredient.dart';
import '../../domain/entities/recipe_line.dart';
import '../../services/inventory_stock_service.dart';
import 'ingredient_form_sheet.dart';
import 'inventory_format.dart';
import 'quantity_unit_field.dart';

/// Una línea en edición: insumo + cantidad en su unidad base.
class RecipeDraftLine {
  final String ingredientId;
  double? quantity;
  RecipeDraftLine(this.ingredientId, this.quantity);
}

/// Estado del editor, para que el form que lo contiene lea las líneas
/// al guardar (ej. el form de producto guarda la receta junto con él).
class RecipeDraft extends ChangeNotifier {
  final List<RecipeDraftLine> lines = [];
  List<({String ingredientId, double quantity})> _initial = const [];

  void load(List<RecipeLine> recipe) {
    lines
      ..clear()
      ..addAll(recipe.map((r) => RecipeDraftLine(r.ingredientId, r.quantity)));
    _initial = _snapshot();
    notifyListeners();
  }

  List<({String ingredientId, double quantity})> _snapshot() => [
        for (final l in lines)
          if ((l.quantity ?? 0) > 0) (ingredientId: l.ingredientId, quantity: l.quantity!),
      ];

  List<({String ingredientId, double quantity})> get valid => _snapshot();

  bool get hasChanges {
    final now = valid;
    if (now.length != _initial.length) return true;
    for (var i = 0; i < now.length; i++) {
      if (now[i].ingredientId != _initial[i].ingredientId ||
          (now[i].quantity - _initial[i].quantity).abs() > 1e-9) {
        return true;
      }
    }
    return false;
  }

  void markSaved() => _initial = _snapshot();

  void add(String ingredientId, [double? qty]) {
    lines.add(RecipeDraftLine(ingredientId, qty));
    notifyListeners();
  }

  void remove(int i) {
    lines.removeAt(i);
    notifyListeners();
  }

  void setQty(int i, double? q) {
    lines[i].quantity = q;
    notifyListeners();
  }

  double cost(InventoryStockService stock) {
    var total = 0.0;
    for (final l in lines) {
      total += (l.quantity ?? 0) * (stock.byId(l.ingredientId)?.avgCost ?? 0);
    }
    return total;
  }
}

/// Editor de receta (lista de insumos con cantidades + costo/margen).
///
/// [salePrice]: precio de venta de lo que se está costeando, para mostrar
/// el % de costo (food cost) y la ganancia por unidad. [resaleName]:
/// si viene, ofrece "Se vende tal cual" (crea un insumo con ese nombre y
/// lo agrega 1:1 — gaseosas, agua, paquetes).
class RecipeEditor extends StatelessWidget {
  final RecipeDraft draft;
  final double? salePrice;
  final String? Function()? resaleName;
  final String emptyHint;

  const RecipeEditor({
    super.key,
    required this.draft,
    this.salePrice,
    this.resaleName,
    this.emptyHint = 'Sin receta: vender este producto no descuenta inventario.',
  });

  @override
  Widget build(BuildContext context) {
    final stock = Get.find<InventoryStockService>();
    return AnimatedBuilder(
      animation: draft,
      builder: (context, _) => Obx(() {
        // Reactivo a cambios de stock/costos (ej. otro dispositivo compró).
        final _ = stock.ingredients.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (draft.lines.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  emptyHint,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            for (var i = 0; i < draft.lines.length; i++)
              _LineRow(
                key: ValueKey('${draft.lines[i].ingredientId}_$i'),
                line: draft.lines[i],
                ingredient: stock.byId(draft.lines[i].ingredientId),
                onQty: (q) => draft.setQty(i, q),
                onRemove: () => draft.remove(i),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final ing = await showIngredientPicker(
                      context,
                      exclude: draft.lines.map((l) => l.ingredientId).toSet(),
                    );
                    if (ing != null) draft.add(ing.id, ing.unit == IngredientUnit.unit ? 1 : null);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar insumo'),
                ),
                if (resaleName != null && draft.lines.isEmpty)
                  TextButton.icon(
                    onPressed: () => _addResale(context, stock),
                    icon: const Icon(Icons.local_drink_outlined),
                    label: const Text('Se vende tal cual'),
                  ),
              ],
            ),
            if (draft.lines.isNotEmpty) ...[
              const SizedBox(height: 12),
              _CostSummary(cost: draft.cost(stock), price: salePrice),
            ],
          ],
        );
      }),
    );
  }

  /// "Se vende tal cual": el producto ES el insumo (gaseosa, agua…).
  Future<void> _addResale(BuildContext context, InventoryStockService stock) async {
    final name = resaleName?.call()?.trim() ?? '';
    if (name.isEmpty) {
      AppSnackbar.show('Falta el nombre', 'Escribí primero el nombre del producto.');
      return;
    }
    final existing =
        stock.ingredients.firstWhereOrNull((i) => i.name.toLowerCase() == name.toLowerCase());
    if (existing != null) {
      draft.add(existing.id, 1);
      return;
    }
    final created = await showIngredientFormSheet(context, suggestedName: name);
    if (created != null) draft.add(created.id, 1);
  }
}

class _LineRow extends StatelessWidget {
  final RecipeDraftLine line;
  final Ingredient? ingredient;
  final ValueChanged<double?> onQty;
  final VoidCallback onRemove;

  const _LineRow({
    super.key,
    required this.line,
    required this.ingredient,
    required this.onQty,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final ing = ingredient;
    final lineCost = (line.quantity ?? 0) * (ing?.avgCost ?? 0);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
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
                child: Text(
                  ing?.name ?? 'Insumo eliminado',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ing == null ? AppColors.error : AppColors.textPrimary,
                  ),
                ),
              ),
              if (ing != null && ing.avgCost > 0)
                Text(
                  CurrencyFormatter.format(lineCost),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              IconButton(
                tooltip: 'Quitar',
                icon: const Icon(Icons.close, size: 18),
                onPressed: onRemove,
              ),
            ],
          ),
          if (ing != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: QuantityUnitField(
                baseUnit: ing.unit,
                initialBaseValue: line.quantity,
                label: 'Cantidad por unidad vendida',
                onChanged: onQty,
              ),
            ),
        ],
      ),
    );
  }
}

class _CostSummary extends StatelessWidget {
  final double cost;
  final double? price;
  const _CostSummary({required this.cost, this.price});

  @override
  Widget build(BuildContext context) {
    final p = price ?? 0;
    final pct = p > 0 ? cost / p * 100 : null;
    // Referencia de la industria: food cost sano ≈ 25–35 %.
    final color = pct == null
        ? AppColors.textSecondary
        : pct <= 35
            ? AppColors.success
            : pct <= 45
                ? AppColors.warning
                : AppColors.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Costo de la receta',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(
                  cost > 0 ? CurrencyFormatter.format(cost) : 'Sin costos cargados',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          if (pct != null && cost > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${fmtNumber(double.parse(pct.toStringAsFixed(1)))} % del precio',
                    style: TextStyle(fontWeight: FontWeight.w800, color: color)),
                Text('Ganás ${CurrencyFormatter.format(p - cost)} por unidad',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
        ],
      ),
    );
  }
}

/// Hoja para editar y GUARDAR directo la receta de una variante o un
/// extra (no dependen de un form más grande). Funciona sin internet.
Future<void> showRecipeEditorSheet(
  BuildContext context, {
  required RecipeOwnerType ownerType,
  required String ownerId,
  required String title,
  String? subtitle,
  double? salePrice,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RecipeSheet(
      ownerType: ownerType,
      ownerId: ownerId,
      title: title,
      subtitle: subtitle,
      salePrice: salePrice,
    ),
  );
}

class _RecipeSheet extends StatefulWidget {
  final RecipeOwnerType ownerType;
  final String ownerId;
  final String title;
  final String? subtitle;
  final double? salePrice;

  const _RecipeSheet({
    required this.ownerType,
    required this.ownerId,
    required this.title,
    this.subtitle,
    this.salePrice,
  });

  @override
  State<_RecipeSheet> createState() => _RecipeSheetState();
}

class _RecipeSheetState extends State<_RecipeSheet> {
  final _draft = RecipeDraft();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _draft.load(Get.find<InventoryStockService>().recipeOf(widget.ownerType, widget.ownerId));
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final r = await GetIt.instance<InventoryRepository>().setRecipe(
      ownerType: widget.ownerType,
      ownerId: widget.ownerId,
      lines: _draft.valid,
    );
    Get.find<InventoryStockService>().reloadLocal();
    if (!mounted) return;
    setState(() => _saving = false);
    r.fold(
      (f) => AppSnackbar.show('No se pudo guardar la receta', f.message),
      (res) {
        AppSnackbar.show(
          'Receta guardada',
          res.synced ? widget.title : '${widget.title} · se sincroniza al volver la señal',
        );
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('Receta · ${widget.title}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                if (widget.subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(widget.subtitle!,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                RecipeEditor(
                  draft: _draft,
                  salePrice: widget.salePrice,
                  emptyHint: widget.ownerType == RecipeOwnerType.modifier
                      ? 'Sin receta: este extra no descuenta inventario.'
                      : 'Sin receta adicional: esta variante descuenta solo la receta del producto.',
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.check),
                  label: const Text('Guardar receta'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
