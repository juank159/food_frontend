import 'package:flutter/material.dart';
import '../../../suppliers/presentation/price_history_section.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../products/data/datasources/product_local_datasource.dart';
import '../../data/inventory_repository.dart';
import '../../domain/entities/ingredient.dart';
import '../../domain/entities/ingredient_movement.dart';
import '../../domain/entities/recipe_line.dart';
import '../../services/inventory_stock_service.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/ingredient_form_sheet.dart';
import '../widgets/inventory_format.dart';
import 'inventory_page.dart';
import 'stock_operation_page.dart';

/// Detalle de un insumo: stock, costos, en qué recetas se usa e
/// historial completo (quién, cuándo, por qué).
class IngredientDetailPage extends StatefulWidget {
  const IngredientDetailPage({super.key});

  @override
  State<IngredientDetailPage> createState() => _IngredientDetailPageState();
}

class _IngredientDetailPageState extends State<IngredientDetailPage> {
  final _stock = Get.find<InventoryStockService>();
  final _repo = GetIt.instance<InventoryRepository>();
  late final String _id;
  List<IngredientMovement> _movements = const [];
  bool _loading = true;

  /// id de producto / variante → nombre legible para "Se usa en".
  final Map<String, String> _productNames = {};
  final Map<String, String> _variantNames = {};

  @override
  void initState() {
    super.initState();
    _id = Get.parameters['id'] ?? '';
    _load();
    _loadNames();
  }

  Future<void> _load() async {
    final list = await _repo.movements(ingredientId: _id, limit: 100);
    if (!mounted) return;
    setState(() {
      _movements = list;
      _loading = false;
    });
  }

  Future<void> _loadNames() async {
    final products = await GetIt.instance<ProductLocalDataSource>().peekCachedProducts();
    if (products == null || !mounted) return;
    setState(() {
      for (final m in products) {
        final p = m.toEntity();
        _productNames[p.id] = p.name;
        for (final v in p.variants) {
          _variantNames[v.id] = '${p.name} · ${v.name}';
        }
      }
    });
  }

  String _usageLabel(RecipeLine r) {
    switch (r.ownerType) {
      case RecipeOwnerType.product:
        return _productNames[r.productId] ?? 'Producto';
      case RecipeOwnerType.variant:
        return '${_variantNames[r.variantId] ?? 'Variante'} (variante)';
      case RecipeOwnerType.modifier:
        return '${_stock.modifiers[r.modifierId]?.name ?? 'Extra'} (extra)';
    }
  }

  Future<void> _operation(StockOperationMode mode) async {
    await Get.toNamed(AppRoutes.inventoryOperation, arguments: {'mode': mode, 'ingredientId': _id});
    _load();
  }

  Future<void> _delete(Ingredient ing) async {
    final usages = _stock.usagesOf(ing.id).length;
    final ok = await confirmInventoryAction(
      context,
      title: 'Eliminar insumo',
      message: usages > 0
          ? '"${ing.name}" se usa en $usages receta${usages == 1 ? '' : 's'}. Si lo '
              'eliminás, esos productos dejan de descontarlo. El historial se conserva.'
          : '¿Eliminar "${ing.name}"? El historial se conserva.',
      confirmText: 'Eliminar',
      destructive: true,
    );
    if (!ok) return;
    final r = await _repo.deleteIngredient(ing.id);
    _stock.reloadLocal();
    r.fold(
      (f) => AppSnackbar.show('No se pudo eliminar', f.message),
      (res) {
        AppSnackbar.show('Insumo eliminado',
            res.synced ? ing.name : '${ing.name} · se sincroniza al volver la señal');
        Get.back();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Obx(() {
          final ing = _stock.byId(_id);
          if (ing == null) {
            return Column(
              children: [
                const AppGradientHeader(title: 'Insumo'),
                const Expanded(
                  child: AppEmptyState(
                    icon: Icons.search_off,
                    title: 'No encontrado',
                    message: 'Este insumo ya no existe.',
                  ),
                ),
              ],
            );
          }
          final usages = _stock.usagesOf(ing.id);
          final pending = _stock.pendingMovements.where((m) => m.ingredientId == ing.id).toList();
          final history = [
            ...pending,
            ..._movements.where((m) => !m.pendingSync),
          ];
          final color = ing.isOut
              ? AppColors.error
              : ing.isLow
                  ? AppColors.warning
                  : AppColors.success;
          return Column(
            children: [
              AppGradientHeader(
                title: ing.name,
                subtitle: [
                  ing.unit.label,
                  if (ing.category != null && ing.category!.isNotEmpty) ing.category!,
                ].join(' · '),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (v) async {
                    if (v == 'edit') {
                      await showIngredientFormSheet(context, editing: ing);
                    } else if (v == 'delete') {
                      await _delete(ing);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
                chips: [
                  AppKpiChip(
                    icon: Icons.inventory_2_outlined,
                    label: 'Stock',
                    value: fmtQty(ing.currentStock, ing.unit),
                  ),
                  AppKpiChip(
                    icon: Icons.warning_amber_rounded,
                    label: 'Mínimo',
                    value: ing.minStock > 0 ? fmtQty(ing.minStock, ing.unit) : '—',
                  ),
                  AppKpiChip(
                    icon: Icons.attach_money,
                    label: 'Costo / ${ing.unit.short}',
                    value: ing.avgCost > 0 ? CurrencyFormatter.format(ing.avgCost) : '—',
                  ),
                  AppKpiChip(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Valor',
                    value: CurrencyFormatter.format(ing.stockValue),
                  ),
                ],
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _stock.refresh();
                    await _load();
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (ing.isOut || ing.isLow)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: color),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  ing.currentStock < 0
                                      ? 'Stock negativo: se vendió más de lo registrado. '
                                          'Registrá la compra que falta o hacé un conteo.'
                                      : ing.isOut
                                          ? 'Agotado: se puede seguir vendiendo, pero conviene reponer.'
                                          : 'Stock bajo: quedan menos del mínimo.',
                                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            // Compra con proveedor y factura (módulo de proveedores).
                            onPressed: () => Get.toNamed(AppRoutes.purchaseNew, arguments: {
                              'lines': [
                                {'ingredientId': ing.id},
                              ],
                            }),
                            icon: const Icon(Icons.local_shipping_outlined, size: 18),
                            label: const Text('Compra'),
                            style: FilledButton.styleFrom(textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _operation(StockOperationMode.waste),
                            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                            label: const Text('Merma'),
                            style: OutlinedButton.styleFrom(textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _operation(StockOperationMode.adjust),
                            icon: const Icon(Icons.tune, size: 18),
                            label: const Text('Ajustar'),
                            style: OutlinedButton.styleFrom(textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      if (ing.lastCost != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Última compra a ${CurrencyFormatter.format(ing.lastCost!)} por ${ing.unit.short}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                      PriceHistorySection(ingredientId: ing.id, unit: ing.unit),
                      const SizedBox(height: 20),
                      const Text('Se usa en',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      if (usages.isEmpty)
                        const Text(
                          'Ningún producto lo usa todavía. Agregalo a la receta de un '
                          'producto (Productos → editar → Receta e inventario).',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      for (final u in usages)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.restaurant_menu, size: 20),
                          title: Text(_usageLabel(u)),
                          trailing: Text('${fmtQty(u.quantity, ing.unit)} c/u',
                              style: const TextStyle(color: AppColors.textSecondary)),
                        ),
                      const SizedBox(height: 16),
                      const Text('Historial',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      if (_loading && history.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (!_loading && history.isEmpty)
                        const Text('Sin movimientos todavía.',
                            style: TextStyle(color: AppColors.textSecondary)),
                      for (final m in history)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: MovementTile(movement: m, ingredient: ing),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
