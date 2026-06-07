import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../employees/domain/entities/employee.dart';
import '../controllers/employee_report_controller.dart';

/// Employee Report Page
///
/// Estructura:
///
///   1) `AppGradientHeader` con KPI hero del top vendedor + chips con
///      total empleados, ventas del equipo y rating promedio.
///   2) Lista de empleados ordenada por ventas descendente, con badge
///      "TOP" en el primero y posición numerada para el resto.
class EmployeeReportPage extends GetView<EmployeeReportController> {
  const EmployeeReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(controller: controller),
            const SizedBox(height: 12),
            Expanded(child: _EmployeesList(controller: controller)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── Header ───────────────────────────────

class _Header extends StatelessWidget {
  final EmployeeReportController controller;
  const _Header({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final r = controller.report.value;
      final top = r.topSeller;
      return AppGradientHeader(
        title: 'Reporte de empleados',
        subtitle: 'Desempeño del equipo',
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        trailing: IconButton(
          tooltip: 'Refrescar',
          onPressed: controller.refresh,
          icon: const Icon(Icons.refresh, color: Colors.white),
        ),
        hero: AppKpiHero(
          icon: Icons.emoji_events_outlined,
          label: top != null ? 'Top vendedor' : 'Equipo',
          value: top?.fullName ?? 'Sin ventas registradas',
          hint: top != null
              ? '${CurrencyFormatter.format(top.totalSalesAmount)} • '
                  '${top.totalOrdersHandled} órdenes'
              : 'Aún no hay ventas asignadas a empleados.',
        ),
        chips: [
          AppKpiChip(
            icon: Icons.group_outlined,
            label: 'Equipo',
            value: r.totalEmployees.toString(),
          ),
          AppKpiChip(
            icon: Icons.payments_outlined,
            label: 'Ventas',
            value: CurrencyFormatter.formatCompact(r.teamSales),
          ),
          AppKpiChip(
            icon: Icons.receipt_long_outlined,
            label: 'Órdenes',
            value: r.teamOrders.toString(),
          ),
          AppKpiChip(
            icon: Icons.star_outline,
            label: 'Rating',
            value: r.teamAverageRating == 0
                ? '—'
                : r.teamAverageRating.toStringAsFixed(1),
          ),
        ],
      );
    });
  }
}

// ─────────────────────────────── List ───────────────────────────────

class _EmployeesList extends StatelessWidget {
  final EmployeeReportController controller;
  const _EmployeesList({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = controller.isLoading.value;
      final report = controller.report.value;
      final err = controller.errorMessage.value;
      final ranked = report.rankedBySales;

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
          icon: Icons.group_outlined,
          title: 'Sin empleados',
          message:
              'Cuando agregues miembros al equipo vas a ver acá su desempeño.',
        );
      }

      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: controller.refresh,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: ranked.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _EmployeeTile(
            employee: ranked[i],
            position: i + 1,
            isTop: i == 0 && ranked[i].totalSalesAmount > 0,
          ),
        ),
      );
    });
  }
}

class _EmployeeTile extends StatelessWidget {
  final Employee employee;
  final int position;
  final bool isTop;

  const _EmployeeTile({
    required this.employee,
    required this.position,
    required this.isTop,
  });

  @override
  Widget build(BuildContext context) {
    final color = isTop ? AppColors.primary : AppColors.info;
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
                                    employee.fullName,
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
                                  '${employee.totalOrdersHandled} órdenes',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Icon(
                                  Icons.star_outline,
                                  size: 12,
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  employee.averageServiceRating == null
                                      ? '—'
                                      : employee.averageServiceRating!
                                          .toStringAsFixed(1),
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
                        CurrencyFormatter.format(employee.totalSalesAmount),
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
