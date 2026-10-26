import 'package:flutter/material.dart';
import '../../../../core/services/branch/branch_service.dart';
import 'package:get/get.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/formatters/datetime_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/ingredient.dart';
import '../../domain/entities/ingredient_movement.dart';
import '../controllers/inventory_controller.dart';
import '../widgets/ingredient_form_sheet.dart';
import '../widgets/inventory_format.dart';
import 'stock_operation_page.dart';

/// Inventario por insumos + recetas: Insumos · Movimientos · Costos.
class InventoryPage extends GetView<InventoryController> {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(controller: controller),
            const SizedBox(height: 10),
            _Tabs(controller: controller),
            const SizedBox(height: 6),
            Expanded(
              child: Obx(() {
                switch (controller.tab.value) {
                  case 1:
                    return _MovementsTab(controller: controller);
                  case 2:
                    return _CostsTab(controller: controller);
                  default:
                    return _IngredientsTab(controller: controller);
                }
              }),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _ActionsBar(controller: controller),
    );
  }
}

class _Header extends StatelessWidget {
  final InventoryController controller;
  const _Header({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = controller.stock;
      return AppGradientHeader(
        title: 'Inventario',
        subtitle: 'Insumos, recetas y costos',
        trailing: s.isRefreshing.value
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Proveedores y compras',
                    onPressed: () => Get.toNamed(AppRoutes.suppliers),
                    icon: const Icon(Icons.local_shipping_outlined, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: 'Actualizar',
                    onPressed: controller.refreshAll,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                  ),
                ],
              ),
        chips: [
          AppKpiChip(
            icon: Icons.inventory_2_outlined,
            label: 'Insumos',
            value: '${s.ingredients.length}',
            onTap: () {
              controller.tab.value = 0;
              controller.filter.value = IngredientFilter.all;
            },
          ),
          AppKpiChip(
            icon: Icons.warning_amber_rounded,
            label: 'Bajos',
            value: '${s.lowCount}',
            onTap: () {
              controller.tab.value = 0;
              controller.filter.value = IngredientFilter.low;
            },
          ),
          AppKpiChip(
            icon: Icons.remove_circle_outline,
            label: 'Agotados',
            value: '${s.outCount}',
            onTap: () {
              controller.tab.value = 0;
              controller.filter.value = IngredientFilter.out;
            },
          ),
          AppKpiChip(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Valor',
            value: CurrencyFormatter.format(controller.inventoryValue),
          ),
        ],
      );
    });
  }
}

class _Tabs extends StatelessWidget {
  final InventoryController controller;
  const _Tabs({required this.controller});

  @override
  Widget build(BuildContext context) {
    const labels = ['Insumos', 'Movimientos', 'Costos'];
    const icons = [Icons.inventory_2_outlined, Icons.history, Icons.pie_chart_outline];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Obx(
        () => Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < labels.length - 1 ? 8 : 0),
                  child: AppFilterChip(
                    label: labels[i],
                    icon: icons[i],
                    selected: controller.tab.value == i,
                    onTap: () => controller.tab.value = i,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── Insumos ───────────────────────────────

class _IngredientsTab extends StatelessWidget {
  final InventoryController controller;
  const _IngredientsTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar insumo o grupo…',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  onChanged: (v) => controller.search.value = v,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 36,
          child: Obx(() {
            final f = controller.filter.value;
            return ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                AppFilterChip(
                  label: 'Todos',
                  selected: f == IngredientFilter.all,
                  onTap: () => controller.filter.value = IngredientFilter.all,
                ),
                AppFilterChip(
                  label: 'Stock bajo',
                  icon: Icons.warning_amber_rounded,
                  selected: f == IngredientFilter.low,
                  onTap: () => controller.filter.value = IngredientFilter.low,
                ),
                AppFilterChip(
                  label: 'Agotados',
                  icon: Icons.remove_circle_outline,
                  selected: f == IngredientFilter.out,
                  onTap: () => controller.filter.value = IngredientFilter.out,
                ),
              ],
            );
          }),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Obx(() {
            final s = controller.stock;
            final list = controller.visibleIngredients;
            final pendingIds = s.pendingMovements.map((m) => m.ingredientId).toSet();
            if (s.ingredients.isEmpty) {
              if (s.isRefreshing.value) {
                return const Center(child: CircularProgressIndicator());
              }
              return AppEmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Empezá con tus insumos',
                message: 'Cargá la materia prima que comprás (ej. "Arepa tipo A") y '
                    'después, en cada producto, armá su receta. Al vender se '
                    'descuenta sola.',
                actionLabel: 'Crear primer insumo',
                actionIcon: Icons.add,
                onAction: () => showIngredientFormSheet(context),
              );
            }
            if (list.isEmpty) {
              return const AppEmptyState(
                icon: Icons.thumb_up_alt_outlined,
                title: 'Nada por acá',
                message: 'Ningún insumo coincide con el filtro.',
              );
            }
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: controller.refreshAll,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _IngredientCard(
                  ingredient: list[i],
                  usages: s.usagesOf(list[i].id).length,
                  pending: pendingIds.contains(list[i].id) || list[i].isPendingSync,
                  onTap: () => Get.toNamed(AppRoutes.buildInventoryDetail(list[i].id)),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _IngredientCard extends StatelessWidget {
  final Ingredient ingredient;
  final int usages;
  final bool pending;
  final VoidCallback onTap;

  const _IngredientCard({
    required this.ingredient,
    required this.usages,
    required this.pending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final i = ingredient;
    final color = i.isOut
        ? AppColors.error
        : i.isLow
            ? AppColors.warning
            : AppColors.success;
    final status = i.currentStock < 0
        ? 'Negativo'
        : i.isOut
            ? 'Agotado'
            : i.isLow
                ? 'Stock bajo'
                : 'En stock';
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                i.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (pending)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Tooltip(
                                  message: 'Cambios sin sincronizar (se envían solos)',
                                  child: Icon(Icons.cloud_upload_outlined,
                                      size: 16, color: AppColors.textSecondary),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(status,
                                  style: TextStyle(
                                      fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (i.category != null && i.category!.isNotEmpty) i.category!,
                            usages == 0
                                ? 'Sin usar en recetas'
                                : 'En $usages receta${usages == 1 ? '' : 's'}',
                          ].join(' · '),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _Metric(label: 'Stock', value: fmtQty(i.currentStock, i.unit), color: color),
                            const SizedBox(width: 16),
                            _Metric(
                              label: 'Mínimo',
                              value: i.minStock > 0 ? fmtQty(i.minStock, i.unit) : '—',
                              color: AppColors.textSecondary,
                            ),
                            const Spacer(),
                            if (i.avgCost > 0)
                              _Metric(
                                label: 'Costo / ${i.unit.short}',
                                value: CurrencyFormatter.format(i.avgCost),
                                color: AppColors.textSecondary,
                                end: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool end;
  const _Metric({required this.label, required this.value, required this.color, this.end = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color, height: 1)),
      ],
    );
  }
}

// ─────────────────────────────── Movimientos ───────────────────────────────

class _MovementsTab extends StatelessWidget {
  final InventoryController controller;
  const _MovementsTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 36,
          child: Obx(() {
            final r = controller.movementReason.value;
            return ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                AppFilterChip(
                  label: 'Todos',
                  selected: r == null,
                  onTap: () => controller.movementReason.value = null,
                ),
                for (final reason in [
                  MovementReason.sale,
                  MovementReason.purchase,
                  MovementReason.waste,
                  MovementReason.count,
                  MovementReason.adjustment,
                ])
                  AppFilterChip(
                    label: reason.label,
                    icon: reason.icon,
                    selected: r == reason,
                    onTap: () => controller.movementReason.value = reason,
                  ),
              ],
            );
          }),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Obx(() {
            if (controller.loadingMovements.value && controller.movements.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = controller.visibleMovements;
            if (list.isEmpty) {
              return const AppEmptyState(
                icon: Icons.history,
                title: 'Sin movimientos',
                message: 'Acá vas a ver cada venta, compra, merma y conteo, con quién lo hizo.',
              );
            }
            return RefreshIndicator(
              onRefresh: controller.loadMovements,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => MovementTile(
                  movement: list[i],
                  ingredient: controller.stock.byId(list[i].ingredientId),
                  showIngredient: true,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Fila de historial (se usa también en el detalle del insumo).
class MovementTile extends StatelessWidget {
  final IngredientMovement movement;
  final Ingredient? ingredient;
  final bool showIngredient;

  const MovementTile({
    super.key,
    required this.movement,
    required this.ingredient,
    this.showIngredient = false,
  });

  @override
  Widget build(BuildContext context) {
    final m = movement;
    final unit = ingredient?.unit ?? IngredientUnit.unit;
    final detail = [
      if (showIngredient) ingredient?.name ?? 'Insumo',
      if (m.reference != null && m.reference!.isNotEmpty) m.reference!,
      if (m.userName != null) m.userName!,
      if (m.notes != null && m.notes!.isNotEmpty) m.notes!,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: m.reason.color.withValues(alpha: 0.12),
            child: Icon(m.reason.icon, size: 18, color: m.reason.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(m.reason.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (m.pendingSync) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.cloud_upload_outlined, size: 14, color: AppColors.textSecondary),
                      const Text(' pendiente',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
                if (detail.isNotEmpty)
                  Text(detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Text('${DateTimeFormatter.dateOnly(m.createdAt)} · ${DateTimeFormatter.time12(m.createdAt)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmtDelta(m.delta, unit),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: m.delta > 0
                      ? AppColors.success
                      : m.delta < 0
                          ? AppColors.error
                          : AppColors.textSecondary,
                ),
              ),
              if (!m.pendingSync)
                Text('Quedan ${fmtQty(m.stockAfter, unit)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Costos ───────────────────────────────

class _CostsTab extends StatelessWidget {
  final InventoryController controller;
  const _CostsTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final rows = controller.foodCostRows;
      final without = controller.productsWithoutRecipe;
      if (rows.isEmpty) {
        return const AppEmptyState(
          icon: Icons.pie_chart_outline,
          title: 'Todavía sin recetas',
          message: 'Abrí un producto (Productos → editar) y en "Receta e inventario" '
              'agregá los insumos que lleva. Acá vas a ver cuánto te cuesta cada '
              'plato y cuánto ganás.',
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'El "% de costo" es cuánto del precio se va en insumos. En comidas, '
              'lo sano suele estar entre 25 % y 35 %.'
              '${without > 0 ? '\n$without producto${without == 1 ? '' : 's'} todavía sin receta (no descuentan inventario).' : ''}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          for (final r in rows) _CostRow(row: r),
        ],
      );
    });
  }
}

class _CostRow extends StatelessWidget {
  final FoodCostRow row;
  const _CostRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final color = row.price <= 0
        ? AppColors.textSecondary
        : row.pct <= 35
            ? AppColors.success
            : row.pct <= 45
                ? AppColors.warning
                : AppColors.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  'Precio ${CurrencyFormatter.format(row.price)} · Costo ${CurrencyFormatter.format(row.cost)}'
                  '${row.missingCosts ? ' · faltan costos' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: row.missingCosts ? AppColors.warning : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(row.price > 0 ? '${row.pct.toStringAsFixed(0)} %' : '—',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
              Text('Ganás ${CurrencyFormatter.format(row.margin)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Acciones ───────────────────────────────

const _actionText = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);

class _ActionsBar extends StatelessWidget {
  final InventoryController controller;
  const _ActionsBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    Widget action(IconData icon, String label, VoidCallback onTap, {bool primary = false}) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: primary
              ? FilledButton.icon(
                  onPressed: onTap,
                  icon: Icon(icon, size: 18),
                  label: Text(label, overflow: TextOverflow.ellipsis),
                  style: FilledButton.styleFrom(
                    textStyle: _actionText,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: onTap,
                  icon: Icon(icon, size: 18),
                  label: Text(label, overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    textStyle: _actionText,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            // Compra con proveedor, factura y cuentas por pagar.
            action(Icons.local_shipping_outlined, 'Compra',
                () => Get.toNamed(AppRoutes.purchaseNew),
                primary: true),
            action(Icons.delete_sweep_outlined, 'Merma',
                () => Get.toNamed(AppRoutes.inventoryOperation,
                    arguments: {'mode': StockOperationMode.waste})),
            action(Icons.fact_check_outlined, 'Conteo', () => Get.toNamed(AppRoutes.inventoryCount)),
            if (BranchService.maybe?.isMulti ?? false)
              action(Icons.swap_horiz, 'Traslado',
                  () => Get.toNamed(AppRoutes.inventoryOperation,
                      arguments: {'mode': StockOperationMode.transfer})),
            action(Icons.add, 'Insumo', () => showIngredientFormSheet(context)),
          ],
        ),
      ),
    );
  }
}
