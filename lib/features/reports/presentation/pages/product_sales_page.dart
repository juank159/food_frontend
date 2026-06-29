import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/product_sales_report.dart';
import '../controllers/product_sales_controller.dart';

class ProductSalesPage extends GetView<ProductSalesController> {
  const ProductSalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            _buildFilters(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ────────────────────────── Header ──────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Obx(() {
      final r = controller.report.value;
      final top = r.topProduct;
      return AppGradientHeader(
        title: 'Productos top',
        subtitle: controller.presetLabel,
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
          icon: Icons.emoji_events_outlined,
          label: top != null ? '# 1 — ${top.productName}' : 'Sin datos',
          value: top != null ? '${top.unitsSold} uds' : '—',
          hint: top != null
              ? '${r.distinctProducts} productos · ${r.totalUnitsSold} uds totales'
              : 'Ajusta el período para ver resultados',
        ),
        chips: [
          AppKpiChip(
            icon: Icons.inventory_2_outlined,
            label: 'Productos',
            value: r.distinctProducts.toString(),
          ),
          AppKpiChip(
            icon: Icons.shopping_cart_outlined,
            label: 'Uds vendidas',
            value: r.totalUnitsSold.toString(),
          ),
          AppKpiChip(
            icon: Icons.payments_outlined,
            label: 'Ingresos',
            value: CurrencyFormatter.format(r.totalRevenue),
          ),
        ],
      );
    });
  }

  // ────────────────────────── Filtros ─────────────────────────────

  Widget _buildFilters() {
    final presets = [
      (ProductSalesPreset.today, 'Hoy'),
      (ProductSalesPreset.yesterday, 'Ayer'),
      (ProductSalesPreset.thisWeek, 'Esta semana'),
      (ProductSalesPreset.thisMonth, 'Este mes'),
    ];
    return Obx(() {
      return Container(
        color: AppColors.cardBackground,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: presets.map((e) {
              final selected = controller.preset.value == e.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(e.$2),
                  selected: selected,
                  onSelected: (_) => controller.selectPreset(e.$1),
                  selectedColor: AppColors.primary,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.normal,
                    fontSize: 13,
                  ),
                  backgroundColor: AppColors.background,
                  side: BorderSide(
                    color:
                        selected ? AppColors.primary : AppColors.border,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                ),
              );
            }).toList(),
          ),
        ),
      );
    });
  }

  // ────────────────────────── Cuerpo ──────────────────────────────

  Widget _buildBody() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }
      if (controller.error.value.isNotEmpty) {
        return _ErrorState(
          message: controller.error.value,
          onRetry: controller.refresh,
        );
      }
      final items = controller.report.value.items;
      if (items.isEmpty) {
        return _EmptyState(preset: controller.presetLabel);
      }
      return _ProductList(items: items);
    });
  }
}

// ─────────────────────── Lista de productos ──────────────────────

class _ProductList extends StatelessWidget {
  final List<ProductSalesItem> items;
  const _ProductList({required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      itemCount: items.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '${items.length} PRODUCTOS VENDIDOS',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
          );
        }
        return _ProductRow(item: items[i - 1]);
      },
    );
  }
}

class _ProductRow extends StatelessWidget {
  final ProductSalesItem item;
  const _ProductRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rank = item.rank;
    final isTop3 = rank <= 3;

    // Colores del podio
    final Color rankColor;
    final Color rankBg;
    if (rank == 1) {
      rankColor = const Color(0xFFB8860B); // dorado oscuro
      rankBg = const Color(0xFFFFF8DC);
    } else if (rank == 2) {
      rankColor = const Color(0xFF607D8B); // plata
      rankBg = const Color(0xFFECEFF1);
    } else if (rank == 3) {
      rankColor = const Color(0xFF8D4E2A); // bronce
      rankBg = const Color(0xFFFBE9E7);
    } else {
      rankColor = AppColors.textSecondary;
      rankBg = AppColors.background;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isTop3
              ? rankColor.withValues(alpha: 0.35)
              : AppColors.border,
          width: isTop3 ? 1.5 : 1,
        ),
        boxShadow: isTop3
            ? [
                BoxShadow(
                  color: rankColor.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Badge de posición
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: rankBg,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: rank <= 3
                  ? Text(
                      rank == 1
                          ? '🥇'
                          : rank == 2
                              ? '🥈'
                              : '🥉',
                      style: const TextStyle(fontSize: 18),
                    )
                  : Text(
                      '#$rank',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: rankColor,
                      ),
                    ),
            ),
            const SizedBox(width: 12),

            // Nombre + categoría
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.categoryName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Métricas
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_cart_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${item.unitsSold} uds',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isTop3 ? rankColor : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  CurrencyFormatter.format(item.totalRevenue),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────── Estados vacío / error ──────────────────────

class _EmptyState extends StatelessWidget {
  final String preset;
  const _EmptyState({required this.preset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_outlined,
                size: 64,
                color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'Sin ventas registradas',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'No hay órdenes completadas en "$preset".\nCambia el período para ver resultados.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
