import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/navigation_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../orders/domain/entities/order.dart' as order_entity;
import '../controllers/sales_report_controller.dart';

/// Sales Report Page
///
/// Estructura:
///
///   1) `AppGradientHeader` con KPI hero (total facturado del rango) +
///      chips de stats (órdenes, ticket, completadas, canceladas).
///   2) Filtros de rango (Hoy / 7d / 30d / Custom).
///   3) Lista de órdenes del rango — tipo "transactions feed".
///
/// La lista usa un card propio reducido (no el `OrderCard` completo de
/// /orders) para mantener foco en monto + estado, que es lo que importa
/// en un reporte.
class SalesReportPage extends GetView<SalesReportController> {
  const SalesReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(controller: controller),
            const SizedBox(height: 12),
            _RangeFilters(controller: controller),
            const SizedBox(height: 8),
            Expanded(child: _OrdersList(controller: controller)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── Header ───────────────────────────────

class _Header extends StatelessWidget {
  final SalesReportController controller;
  const _Header({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final r = controller.report.value;
      return AppGradientHeader(
        title: 'Reporte de ventas',
        subtitle: controller.rangeLabel,
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
          icon: Icons.payments_outlined,
          label: 'Total facturado',
          value: CurrencyFormatter.format(r.totalRevenue),
          hint: '${r.totalOrders} '
              '${r.totalOrders == 1 ? "orden" : "órdenes"} • Ticket '
              '${CurrencyFormatter.format(r.averageOrderValue)}',
        ),
        chips: [
          AppKpiChip(
            icon: Icons.receipt_long_outlined,
            label: 'Órdenes',
            value: r.totalOrders.toString(),
          ),
          AppKpiChip(
            icon: Icons.show_chart,
            label: 'Ticket',
            value: CurrencyFormatter.formatCompact(r.averageOrderValue),
          ),
          AppKpiChip(
            icon: Icons.check_circle_outline,
            label: 'Completas',
            value: r.completedCount.toString(),
          ),
          AppKpiChip(
            icon: Icons.cancel_outlined,
            label: 'Canceladas',
            value: r.cancelledCount.toString(),
          ),
        ],
      );
    });
  }
}

// ─────────────────────────────── Range filters ───────────────────────────────

class _RangeFilters extends StatelessWidget {
  final SalesReportController controller;
  const _RangeFilters({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: SizedBox(
        height: 36,
        child: Obx(() {
          final p = controller.preset.value;
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            children: [
              AppFilterChip(
                label: 'Hoy',
                selected: p == SalesRangePreset.today,
                onTap: () => controller.selectPreset(SalesRangePreset.today),
              ),
              AppFilterChip(
                label: '7 días',
                selected: p == SalesRangePreset.last7Days,
                onTap: () =>
                    controller.selectPreset(SalesRangePreset.last7Days),
              ),
              AppFilterChip(
                label: '30 días',
                selected: p == SalesRangePreset.last30Days,
                onTap: () =>
                    controller.selectPreset(SalesRangePreset.last30Days),
              ),
              AppFilterChip(
                label: 'Personalizado',
                icon: Icons.calendar_today,
                selected: p == SalesRangePreset.custom,
                onTap: () => _pickCustom(context),
              ),
            ],
          );
        }),
      ),
    );
  }

  Future<void> _pickCustom(BuildContext context) async {
    final now = DateTime.now();
    final initialFrom =
        controller.dateFrom.value ?? now.subtract(const Duration(days: 7));
    final initialTo = controller.dateTo.value ?? now;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(start: initialFrom, end: initialTo),
      helpText: 'Rango personalizado',
      saveText: 'Aplicar',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.primary,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      controller.selectCustomRange(picked.start, picked.end);
    }
  }
}

// ─────────────────────────────── List ───────────────────────────────

class _OrdersList extends StatelessWidget {
  final SalesReportController controller;
  const _OrdersList({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = controller.isLoading.value;
      final orders = controller.orders;
      final err = controller.errorMessage.value;

      if (loading && orders.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (err.isNotEmpty && orders.isEmpty) {
        return AppErrorState(
          message: err,
          onRetry: controller.refresh,
        );
      }
      if (orders.isEmpty) {
        return const AppEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'Sin órdenes en este rango',
          message:
              'Probá con otro rango de fechas o creá la primera orden del día.',
        );
      }

      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: controller.refresh,
        child: LayoutBuilder(builder: (context, constraints) {
          // Padding lateral más generoso en wide para que las cards
          // respiren — pero usando el ancho completo (sin Center +
          // ConstrainedBox).
          final isWide = constraints.maxWidth >= 900;
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              isWide ? 32 : 16,
              8,
              isWide ? 32 : 16,
              24,
            ),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _OrderTile(
              order: orders[i],
              onTap: () => NavigationService.toOrderDetail(orders[i].id),
            ),
          );
        }),
      );
    });
  }
}

class _OrderTile extends StatelessWidget {
  final order_entity.Order order;
  final VoidCallback onTap;

  const _OrderTile({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(order.status);
    final fmt = DateFormat('dd/MM HH:mm');
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
                                      '#${order.orderNumber}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      order.status.displayName,
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
                                '${order.displayDestination} • ${fmt.format(order.createdAt.toLocal())}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(order.totalAmount),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
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

  Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.pendingReview:
        // Self-order pendiente de aprobación — comparte color con
        // pending normal en reportes para no romper agrupaciones
        // visuales de "no completadas".
        return AppColors.warning;
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.confirmed:
      case OrderStatus.preparing:
        return AppColors.info;
      case OrderStatus.ready:
      case OrderStatus.delivered:
        return AppColors.accent;
      case OrderStatus.completed:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }
}
