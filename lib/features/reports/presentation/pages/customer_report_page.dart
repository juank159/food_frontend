import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../customers/domain/entities/customer.dart';
import '../controllers/customer_report_controller.dart';

/// Customer Report Page
///
/// Estructura:
///
///   1) `AppGradientHeader` con KPI hero del top spender + chips con
///      total clientes, nuevos del mes, ticket promedio y total de
///      órdenes registrado por el equipo de clientes.
///   2) Lista de clientes ordenada por gasto descendente, con badge "TOP"
///      en el primero, posición numerada y meta-info (última orden,
///      cantidad de órdenes).
class CustomerReportPage extends GetView<CustomerReportController> {
  const CustomerReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(controller: controller),
            const SizedBox(height: 12),
            Expanded(child: _CustomersList(controller: controller)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── Header ───────────────────────────────

class _Header extends StatelessWidget {
  final CustomerReportController controller;
  const _Header({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final r = controller.report.value;
      final top = r.topSpender;
      return AppGradientHeader(
        title: 'Reporte de clientes',
        subtitle: 'Top compradores y comportamiento',
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
          icon: Icons.workspace_premium_outlined,
          label: top != null ? 'Top spender' : 'Clientes',
          value: top?.fullName ?? 'Sin clientes registrados',
          hint: top != null
              ? '${CurrencyFormatter.format(top.totalSpent)} • '
                  '${top.totalOrders} órdenes'
              : 'Comenzá a registrar clientes para ver su comportamiento.',
        ),
        chips: [
          AppKpiChip(
            icon: Icons.people_outline,
            label: 'Total',
            value: r.totalCustomers.toString(),
          ),
          AppKpiChip(
            icon: Icons.fiber_new_outlined,
            label: 'Nuevos',
            value: r.newThisMonth.toString(),
          ),
          AppKpiChip(
            icon: Icons.show_chart,
            label: 'Promedio',
            value: CurrencyFormatter.formatCompact(r.averageSpend),
          ),
          AppKpiChip(
            icon: Icons.receipt_long_outlined,
            label: 'Órdenes',
            value: r.statistics.totalOrders.toString(),
          ),
        ],
      );
    });
  }
}

// ─────────────────────────────── List ───────────────────────────────

class _CustomersList extends StatelessWidget {
  final CustomerReportController controller;
  const _CustomersList({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = controller.isLoading.value;
      final report = controller.report.value;
      final err = controller.errorMessage.value;
      final ranked = report.rankedBySpend;

      if (loading && ranked.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (err.isNotEmpty && ranked.isEmpty) {
        return AppErrorState(
          message: err,
          onRetry: controller.refresh,
        );
      }
      if (ranked.isEmpty) {
        return const AppEmptyState(
          icon: Icons.people_outline,
          title: 'Sin clientes',
          message:
              'Cuando registres clientes vas a poder ver su ranking de gasto acá.',
        );
      }

      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: controller.refresh,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: ranked.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _CustomerTile(
            customer: ranked[i],
            position: i + 1,
            isTop: i == 0 && ranked[i].totalSpent > 0,
          ),
        ),
      );
    });
  }
}

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  final int position;
  final bool isTop;

  const _CustomerTile({
    required this.customer,
    required this.position,
    required this.isTop,
  });

  @override
  Widget build(BuildContext context) {
    final color = isTop ? AppColors.primary : AppColors.secondary;
    final fmt = DateFormat('dd/MM/yy');
    final lastOrder = customer.lastOrderDate;
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
                      _Rank(position: position, isTop: isTop),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    customer.fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (isTop) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'TOP',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ] else if (customer.isNewThisMonth) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.info
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'NUEVO',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.info,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 12,
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${customer.totalOrders} órdenes',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Icon(
                                  Icons.event_outlined,
                                  size: 12,
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  lastOrder == null
                                      ? 'Sin órdenes'
                                      : fmt.format(lastOrder.toLocal()),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        CurrencyFormatter.format(customer.totalSpent),
                        style: const TextStyle(
                          fontSize: 15,
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
    );
  }
}

class _Rank extends StatelessWidget {
  final int position;
  final bool isTop;
  const _Rank({required this.position, required this.isTop});

  @override
  Widget build(BuildContext context) {
    final color = isTop ? AppColors.primary : AppColors.textSecondary;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Text(
        '#$position',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
