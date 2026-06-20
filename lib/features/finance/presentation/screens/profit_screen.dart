import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/utils/date_period.dart';
import '../../../../core/widgets/widgets.dart';
import '../controllers/expenses_controller.dart' show expenseCategoryLabel;
import '../controllers/profit_controller.dart';

/// Estado de resultados (Ganancias): Ingresos − COGS − Gastos − Nómina.
class ProfitScreen extends StatelessWidget {
  const ProfitScreen({super.key});

  static const _periods = [
    DatePeriod.today,
    DatePeriod.last7Days,
    DatePeriod.thisMonth,
  ];

  @override
  Widget build(BuildContext context) {
    final c = Get.put(ProfitController());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Obx(() => AppGradientHeader(
                  title: 'Ganancias',
                  subtitle: '${c.period.value.label} · '
                      '${c.isProfit ? "Ganancia" : "Pérdida"} '
                      '${CurrencyFormatter.format(c.netProfit.value.abs())}',
                  leading: IconButton(
                    tooltip: 'Volver',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                )),
            _periodBar(c),
            Expanded(
              child: Obx(() {
                if (c.isLoading.value && c.revenue.value == 0) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (c.error.value.isNotEmpty) {
                  return AppErrorState(
                    message: c.error.value,
                    onRetry: c.load,
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: c.load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    children: [
                      _netCard(c),
                      const SizedBox(height: 12),
                      _breakdownCard(c),
                      const SizedBox(height: 12),
                      _expensesByCategory(c),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodBar(ProfitController c) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Obx(() => Row(
            children: _periods
                .map((p) => AppFilterChip(
                      label: p.label,
                      selected: c.period.value == p,
                      onTap: () => c.setPeriod(p),
                    ))
                .toList(),
          )),
    );
  }

  Widget _netCard(ProfitController c) {
    final positive = c.isProfit;
    final color = positive ? AppColors.success : AppColors.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.14), color.withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                positive ? Icons.trending_up : Icons.trending_down,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                positive ? 'Ganancia neta' : 'Pérdida neta',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.format(c.netProfit.value),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Margen neto ${c.netMarginPct.value.toStringAsFixed(1)}% · '
            '${c.ordersCount.value} órdenes',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakdownCard(ProfitController c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _row('Ingresos (ventas)', c.revenue.value, sign: '+'),
          _row('Costo de productos vendidos', c.cogs.value,
              sign: '−', color: AppColors.error),
          const Divider(height: 18),
          _row('Utilidad bruta', c.grossProfit.value,
              bold: true,
              hint: 'Margen ${c.grossMarginPct.value.toStringAsFixed(1)}%'),
          const SizedBox(height: 8),
          _row('Gastos', c.expensesTotal.value,
              sign: '−', color: AppColors.error),
          _row('Nómina pagada', c.payrollTotal.value,
              sign: '−', color: AppColors.error),
          const Divider(height: 18),
          _row(
            c.isProfit ? 'Ganancia neta' : 'Pérdida neta',
            c.netProfit.value,
            bold: true,
            color: c.isProfit ? AppColors.success : AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    double value, {
    String sign = '',
    bool bold = false,
    Color? color,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: bold ? 15 : 13.5,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (hint != null)
                  Text(
                    hint,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$sign${CurrencyFormatter.format(value)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: bold ? 15 : 13.5,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _expensesByCategory(ProfitController c) {
    if (c.expensesByCategory.isEmpty) return const SizedBox.shrink();
    final entries = c.expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gastos por categoría',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        expenseCategoryLabel(e.key),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      CurrencyFormatter.format(e.value),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
