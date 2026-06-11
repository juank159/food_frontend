import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../products/domain/entities/product.dart';
import '../controllers/inventory_report_controller.dart';

/// Inventory Report Page
///
/// Estructura:
///
///   1) `AppGradientHeader` con KPI hero (productos trackeados) + chips
///      con stock OK / bajo / agotados.
///   2) Filtros inline (Todos / Stock bajo / Agotados).
///   3) Lista de productos trackeados — críticos arriba, badges visuales
///      ("Sin stock" rojo, "Bajo" ámbar) y stripe vertical de color.
///
/// El reporte es un snapshot: no hay rangos de fecha porque el stock es
/// el estado actual del catálogo.
class InventoryReportPage extends GetView<InventoryReportController> {
  const InventoryReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(controller: controller),
            const SizedBox(height: 12),
            _Filters(controller: controller),
            const SizedBox(height: 8),
            Expanded(child: _ProductsList(controller: controller)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── Header ───────────────────────────────

class _Header extends StatelessWidget {
  final InventoryReportController controller;
  const _Header({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final r = controller.report.value;
      return AppGradientHeader(
        title: 'Reporte de inventario',
        subtitle: 'Snapshot del stock vigente',
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        trailing: IconButton(
          tooltip: 'Refrescar',
          onPressed: controller.refresh,
          icon: const Icon(Icons.refresh, color: Colors.white),
        ),
        hero: AppKpiHero(
          icon: Icons.warehouse_outlined,
          label: 'Productos trackeados',
          value: r.totalTracked.toString(),
          hint: r.lowStockCount == 0
              ? 'Stock saludable'
              : '${r.lowStockCount} '
                  '${r.lowStockCount == 1 ? "alerta" : "alertas"} de stock',
        ),
        chips: [
          AppKpiChip(
            icon: Icons.check_circle_outline,
            label: 'En stock',
            value: r.inStockCount.toString(),
            onTap: () => controller.selectFilter(InventoryFilter.all),
          ),
          AppKpiChip(
            icon: Icons.warning_amber_rounded,
            label: 'Bajo',
            value: r.lowStockCount.toString(),
            onTap: () => controller.selectFilter(InventoryFilter.low),
          ),
          AppKpiChip(
            icon: Icons.remove_circle_outline,
            label: 'Agotados',
            value: r.outOfStockCount.toString(),
            onTap: () => controller.selectFilter(InventoryFilter.out),
          ),
        ],
      );
    });
  }
}

// ─────────────────────────────── Filters ───────────────────────────────

class _Filters extends StatelessWidget {
  final InventoryReportController controller;
  const _Filters({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: SizedBox(
        height: 36,
        child: Obx(() {
          final f = controller.filter.value;
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            children: [
              AppFilterChip(
                label: 'Todos',
                selected: f == InventoryFilter.all,
                onTap: () => controller.selectFilter(InventoryFilter.all),
              ),
              AppFilterChip(
                label: 'Stock bajo',
                icon: Icons.warning_amber_rounded,
                selected: f == InventoryFilter.low,
                onTap: () => controller.selectFilter(InventoryFilter.low),
              ),
              AppFilterChip(
                label: 'Agotados',
                icon: Icons.remove_circle_outline,
                selected: f == InventoryFilter.out,
                onTap: () => controller.selectFilter(InventoryFilter.out),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────── List ───────────────────────────────

class _ProductsList extends StatelessWidget {
  final InventoryReportController controller;
  const _ProductsList({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = controller.isLoading.value;
      final report = controller.report.value;
      final err = controller.errorMessage.value;
      final items = controller.visibleProducts;

      if (loading && report.trackedProducts.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (err.isNotEmpty && report.trackedProducts.isEmpty) {
        return AppErrorState(
          message: err,
          onRetry: controller.refresh,
        );
      }
      if (items.isEmpty) {
        // Empty state distinto según el filtro: si está en "agotados" y no
        // hay agotados, es una buena noticia; en "todos" significa que el
        // catálogo no tiene productos con seguimiento de stock.
        final filter = controller.filter.value;
        return AppEmptyState(
          icon: filter == InventoryFilter.all
              ? Icons.warehouse_outlined
              : Icons.check_circle_outline,
          title: filter == InventoryFilter.all
              ? 'Sin productos con seguimiento de stock'
              : 'Todo en orden',
          message: filter == InventoryFilter.all
              ? 'Activá el seguimiento de inventario en tus productos para verlos acá.'
              : 'No hay productos con esta condición — buen trabajo.',
        );
      }

      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: controller.refresh,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) =>
              _ProductTile(product: items[i] as Product),
        ),
      );
    });
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(product);
    final stock = product.currentStock ?? 0;
    final min = product.minStockAlert ?? 0;
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
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
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    product.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _StatusBadge(product: product),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              product.sku == null || product.sku!.isEmpty
                                  ? 'Mín alerta: $min'
                                  : 'SKU ${product.sku} • Mín $min',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            stock.toString(),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: color,
                              height: 1.0,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'unidades',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
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
    );
  }

  Color _statusColor(Product p) {
    if (p.isOutOfStock) return AppColors.error;
    if (p.isLowStock) return AppColors.warning;
    return AppColors.success;
  }
}

class _StatusBadge extends StatelessWidget {
  final Product product;
  const _StatusBadge({required this.product});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _badge(product);
    if (label == null || color == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  (String?, Color?) _badge(Product p) {
    if (p.isOutOfStock) return ('SIN STOCK', AppColors.error);
    if (p.isLowStock) return ('STOCK BAJO', AppColors.warning);
    return (null, null);
  }
}
