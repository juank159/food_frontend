import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/inventory_item.dart';
import '../controllers/inventory_controller.dart';

/// Inventory Page
///
/// Listado de inventario con KPIs en el header, chips de filtro inline
/// (todos / en stock / bajo / agotados) y cards estilo `OrderCard` con
/// stripe vertical de color (verde/ámbar/rojo) — patrón visual idéntico
/// al resto de la app para que el usuario navegue por inercia.
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
            const SizedBox(height: 12),
            _Filters(controller: controller),
            const SizedBox(height: 8),
            Expanded(child: _ItemsList(controller: controller)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── Header ───────────────────────────────

class _Header extends StatelessWidget {
  final InventoryController controller;
  const _Header({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Forzamos la suscripción a `items` para que los KPIs se
      // recalculen cuando cambia la lista.
      final _ = controller.items.length;
      return AppGradientHeader(
        title: 'Inventario',
        subtitle: 'Control de stock en tiempo real',
        trailing: IconButton(
          tooltip: 'Refrescar',
          onPressed: controller.refresh,
          icon: const Icon(Icons.refresh, color: Colors.white),
        ),
        chips: [
          AppKpiChip(
            icon: Icons.inventory_2_outlined,
            label: 'Productos',
            value: controller.totalCount.toString(),
          ),
          AppKpiChip(
            icon: Icons.check_circle_outline,
            label: 'En stock',
            value: controller.inStockCount.toString(),
            onTap: () => controller.setFilter(InventoryFilter.inStock),
          ),
          AppKpiChip(
            icon: Icons.warning_amber_rounded,
            label: 'Bajo',
            value: controller.lowStockCount.toString(),
            onTap: () => controller.setFilter(InventoryFilter.lowStock),
          ),
          AppKpiChip(
            icon: Icons.remove_circle_outline,
            label: 'Agotados',
            value: controller.outOfStockCount.toString(),
            onTap: () => controller.setFilter(InventoryFilter.outOfStock),
          ),
        ],
      );
    });
  }
}

// ─────────────────────────────── Filters ───────────────────────────────

class _Filters extends StatelessWidget {
  final InventoryController controller;
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
                onTap: () => controller.setFilter(InventoryFilter.all),
              ),
              AppFilterChip(
                label: 'En stock',
                icon: Icons.check_circle_outline,
                selected: f == InventoryFilter.inStock,
                onTap: () => controller.setFilter(InventoryFilter.inStock),
              ),
              AppFilterChip(
                label: 'Stock bajo',
                icon: Icons.warning_amber_rounded,
                selected: f == InventoryFilter.lowStock,
                onTap: () => controller.setFilter(InventoryFilter.lowStock),
              ),
              AppFilterChip(
                label: 'Agotados',
                icon: Icons.remove_circle_outline,
                selected: f == InventoryFilter.outOfStock,
                onTap: () => controller.setFilter(InventoryFilter.outOfStock),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────── List ───────────────────────────────

class _ItemsList extends StatelessWidget {
  final InventoryController controller;
  const _ItemsList({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = controller.isLoading.value;
      final err = controller.errorMessage.value;
      final list = controller.filteredItems;

      if (loading && controller.items.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (err.isNotEmpty && controller.items.isEmpty) {
        return AppErrorState(
          message: err,
          onRetry: controller.refresh,
        );
      }
      if (list.isEmpty) {
        return AppEmptyState(
          icon: _emptyIcon(controller.filter.value),
          title: _emptyTitle(controller.filter.value),
          message: _emptyMessage(controller.filter.value),
        );
      }

      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: controller.refresh,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _InventoryCard(
            item: list[i],
            // El tap sobre la card va al detalle — la página dedicada
            // muestra todo el contexto del item (estado, configuración,
            // histórico). El CTA "Ajustar" sigue yendo directo al form
            // para no agregar fricción cuando ya sabés qué cambiar.
            onTap: () async {
              await Get.toNamed(
                AppRoutes.buildInventoryDetail(list[i].id),
              );
              // Recargamos al volver: si ajustaron desde el detalle el
              // stock ya quedó actualizado en memoria, pero un refresh
              // garantiza que el listado refleje cualquier cambio.
              await controller.refresh();
            },
            onAdjust: () {
              controller.startAdjustment(
                list[i],
                onReady: () => Get.toNamed(AppRoutes.inventoryAdjustment),
              );
            },
          ),
        ),
      );
    });
  }

  IconData _emptyIcon(InventoryFilter f) {
    switch (f) {
      case InventoryFilter.outOfStock:
        return Icons.celebration_outlined;
      case InventoryFilter.lowStock:
        return Icons.thumb_up_alt_outlined;
      case InventoryFilter.inStock:
        return Icons.inventory_2_outlined;
      case InventoryFilter.all:
        return Icons.inventory_2_outlined;
    }
  }

  String _emptyTitle(InventoryFilter f) {
    switch (f) {
      case InventoryFilter.outOfStock:
        return 'No hay productos agotados';
      case InventoryFilter.lowStock:
        return 'Stock saludable';
      case InventoryFilter.inStock:
        return 'Sin productos en stock';
      case InventoryFilter.all:
        return 'No hay productos';
    }
  }

  String _emptyMessage(InventoryFilter f) {
    switch (f) {
      case InventoryFilter.outOfStock:
        return 'Todo lo que trackeás tiene unidades disponibles. Buen trabajo.';
      case InventoryFilter.lowStock:
        return 'Ningún producto está cerca del umbral mínimo.';
      case InventoryFilter.inStock:
        return 'Cargá stock desde el ajuste para empezar a controlar inventario.';
      case InventoryFilter.all:
        return 'Cargá productos desde el módulo de Productos para verlos acá.';
    }
  }
}

// ─────────────────────────────── Card ───────────────────────────────

class _InventoryCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onTap;
  final VoidCallback onAdjust;

  const _InventoryCard({
    required this.item,
    required this.onTap,
    required this.onAdjust,
  });

  @override
  Widget build(BuildContext context) {
    final color = _stripeColor(item);
    final statusLabel = _statusLabel(item);
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
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
                                item.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.sku == null || item.sku!.isEmpty
                              ? 'Sin SKU'
                              : 'SKU ${item.sku}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _StockMetric(
                              label: 'Stock',
                              value: _stockText(item),
                              color: color,
                            ),
                            const SizedBox(width: 14),
                            _StockMetric(
                              label: 'Mínimo',
                              value: item.minStockAlert?.toString() ?? '—',
                              color: AppColors.textSecondary,
                            ),
                            const Spacer(),
                            FilledButton.tonalIcon(
                              onPressed: onAdjust,
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.1),
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.tune, size: 16),
                              label: const Text(
                                'Ajustar',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
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
      ),
    );
  }

  Color _stripeColor(InventoryItem i) {
    if (!i.trackInventory) return AppColors.textHint;
    if (i.isOutOfStock) return AppColors.error;
    if (i.isLowStock) return AppColors.warning;
    return AppColors.success;
  }

  String _statusLabel(InventoryItem i) {
    if (!i.trackInventory) return 'Sin tracking';
    if (i.isOutOfStock) return 'Agotado';
    if (i.isLowStock) return 'Stock bajo';
    return 'En stock';
  }

  String _stockText(InventoryItem i) {
    if (!i.trackInventory) return '—';
    return (i.currentStock ?? 0).toString();
  }
}

class _StockMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StockMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}
