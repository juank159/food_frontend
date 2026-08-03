// lib/features/cash_sessions/presentation/pages/cash_session_history_page.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/date_period.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/cash_session.dart';
import '../controllers/cash_session_history_controller.dart';

/// Historial profesional de sesiones de caja.
///
/// Muestra todas las sesiones del período seleccionado con:
///   - Resumen estadístico del período (cash, otros métodos, gastos).
///   - Filtros por período y estado.
///   - Lista de sesiones, cada una con sus métricas principales.
///
/// Acceso: admin y manager (historial de todos); el cajero puede ver
/// solo las propias — el backend filtra por rol.
class CashSessionHistoryPage extends StatefulWidget {
  const CashSessionHistoryPage({super.key});

  @override
  State<CashSessionHistoryPage> createState() => _CashSessionHistoryPageState();
}

class _CashSessionHistoryPageState extends State<CashSessionHistoryPage> {
  late final CashSessionHistoryController controller;

  static const _periods = [
    DatePeriod.today,
    DatePeriod.yesterday,
    DatePeriod.last7Days,
    DatePeriod.thisMonth,
    DatePeriod.all,
  ];

  @override
  void initState() {
    super.initState();
    controller = Get.find<CashSessionHistoryController>();
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            _buildFilters(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Obx(() {
      final count = controller.sessions.length;
      final label = controller.period.value.label;
      return AppGradientHeader(
        title: 'Historial de Caja',
        subtitle: '$label · $count ${count == 1 ? "sesión" : "sesiones"}',
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        trailing: Obx(() {
          if (controller.isLoading.value) {
            return const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            );
          }
          return GestureDetector(
            onTap: controller.reload,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.refresh, color: Colors.white, size: 20),
            ),
          );
        }),
      );
    });
  }

  // ── Filtros ───────────────────────────────────────────────────────────

  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila 1: períodos
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Obx(
                () => Row(
                  children: _periods
                      .map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: AppFilterChip(
                            label: p.shortLabel,
                            selected: controller.period.value == p,
                            onTap: () => controller.setPeriod(p),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
          // Fila 2: estados
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Obx(
              () => Row(
                children: [
                  _statusChip(
                    label: 'Abiertas',
                    status: CashSessionStatus.open,
                    accent: AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  _statusChip(
                    label: 'Cerradas',
                    status: CashSessionStatus.closed,
                    accent: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  _statusChip(
                    label: 'Anuladas',
                    status: CashSessionStatus.voided,
                    accent: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
        ],
      ),
    );
  }

  Widget _statusChip({
    required String label,
    required CashSessionStatus status,
    required Color accent,
  }) {
    final selected = controller.statusFilter.value == status;
    return AppFilterChip(
      label: label,
      selected: selected,
      onTap: () => controller.toggleStatus(status),
      accentColor: accent,
    );
  }

  // ── Cuerpo ────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return Obx(() {
      if (controller.isLoading.value && controller.sessions.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.error.value.isNotEmpty && controller.sessions.isEmpty) {
        return AppErrorState(
          message: controller.error.value,
          onRetry: controller.reload,
        );
      }
      if (controller.sessions.isEmpty) {
        return const AppEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'Sin sesiones',
          message: 'No hay sesiones de caja en el período seleccionado.',
        );
      }

      return RefreshIndicator(
        onRefresh: controller.reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _buildSummaryStrip(),
            const SizedBox(height: 16),
            ...controller.sessions.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SessionCard(
                  session: s,
                  onTap: () =>
                      Get.toNamed('/cash-history/${s.id}', arguments: s),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ── Resumen del período ────────────────────────────────────────────────

  Widget _buildSummaryStrip() {
    return Obx(() {
      final c = controller;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.bar_chart_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'RESUMEN DEL PERÍODO',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  '${c.sessions.length} ${c.sessions.length == 1 ? "sesión" : "sesiones"}'
                  ' · ${c.closedCount} cerradas',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _SummaryTile(
                    label: 'Efectivo',
                    amount: c.periodCashTotal,
                    icon: Icons.payments_outlined,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryTile(
                    label: 'Otros métodos',
                    amount: c.periodOtherTotal,
                    icon: Icons.credit_card_outlined,
                    color: AppColors.info,
                  ),
                ),
              ],
            ),
            if (c.periodExpensesTotal > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      label: 'Gastos del turno',
                      amount: c.periodExpensesTotal,
                      icon: Icons.money_off_outlined,
                      color: AppColors.error,
                      negative: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryTile(
                      label: 'Neto en caja',
                      amount: c.periodNetCash,
                      icon: Icons.account_balance_wallet_outlined,
                      color: AppColors.primary,
                      hero: true,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }
}

// ─────────────────────── Summary tile ───────────────────────────────────────

class _SummaryTile extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  final bool negative;
  final bool hero;

  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    this.negative = false,
    this.hero = false,
  });

  @override
  Widget build(BuildContext context) {
    final sign = negative ? '−' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: hero ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: hero ? Border.all(color: color.withValues(alpha: 0.3)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$sign${CurrencyFormatter.format(amount)}',
            style: TextStyle(
              fontSize: hero ? 16 : 14,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Session card ───────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final CashSession session;
  final VoidCallback onTap;

  const _SessionCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final diff = session.difference;
    final diffColor = diff == null
        ? null
        : (diff.abs() <= 0.01
              ? AppColors.success
              : (diff < 0 ? AppColors.error : AppColors.warning));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera: estado + fecha ─────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                color: _statusColor(session.status).withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  SessionStatusBadge(status: session.status),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(session.openedAt),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (session.openedByName != null)
                          Text(
                            session.openedByName!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Duración del turno (solo si cerrada)
                  if (session.durationMinutes != null)
                    _DurationBadge(minutes: session.durationMinutes!),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            // ── Métricas ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                children: [
                  // Fila 1: fondo + cobros cash
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCell(
                          label: 'Fondo inicial',
                          amount: session.openingAmount,
                          icon: Icons.savings_outlined,
                          color: AppColors.info,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricCell(
                          label: 'Cobros cash (${session.totalPaymentsCount})',
                          amount: session.totalCashCollected,
                          icon: Icons.payments_outlined,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  // Fila 2: otros métodos + gastos (solo si hay)
                  if (session.totalOtherCollected > 0 ||
                      session.totalCashExpenses > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (session.totalOtherCollected > 0)
                          Expanded(
                            child: _MetricCell(
                              label: 'Otros (${session.totalOtherCount})',
                              amount: session.totalOtherCollected,
                              icon: Icons.credit_card_outlined,
                              color: AppColors.info,
                            ),
                          ),
                        if (session.totalOtherCollected > 0 &&
                            session.totalCashExpenses > 0)
                          const SizedBox(width: 8),
                        if (session.totalCashExpenses > 0)
                          Expanded(
                            child: _MetricCell(
                              label: 'Gastos',
                              amount: session.totalCashExpenses,
                              icon: Icons.money_off_outlined,
                              color: AppColors.error,
                              negative: true,
                            ),
                          ),
                        // Spacer si solo hay uno de los dos para alinear
                        if (session.totalOtherCollected > 0 &&
                            session.totalCashExpenses == 0)
                          const Expanded(child: SizedBox()),
                        if (session.totalOtherCollected == 0 &&
                            session.totalCashExpenses > 0)
                          const Expanded(child: SizedBox()),
                      ],
                    ),
                  ],
                  // Fila 3: esperado + diferencia (si cerrada)
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCell(
                          label: session.isClosed
                              ? 'Esperado al cierre'
                              : 'Esperado en caja',
                          amount: session.currentExpectedAmount,
                          icon: Icons.account_balance_wallet_outlined,
                          color: AppColors.primary,
                          hero: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (session.isClosed && diff != null)
                        Expanded(
                          child: _MetricCell(
                            label: 'Diferencia',
                            amount: diff.abs(),
                            icon: diff.abs() <= 0.01
                                ? Icons.check_circle_outline
                                : Icons.warning_amber_rounded,
                            color: diffColor!,
                            sign: diff.abs() <= 0.01
                                ? '='
                                : (diff < 0 ? '−' : '+'),
                            hero: true,
                          ),
                        )
                      else
                        const Expanded(child: SizedBox()),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(CashSessionStatus s) {
    switch (s) {
      case CashSessionStatus.open:
        return AppColors.success;
      case CashSessionStatus.closed:
        return AppColors.primary;
      case CashSessionStatus.voided:
        return AppColors.textSecondary;
    }
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return DateFormat('dd MMM yyyy · HH:mm', 'es').format(local);
  }
}

// ─────────────────────── Metric cell ─────────────────────────────────────────

class _MetricCell extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  final bool negative;
  final bool hero;
  final String? sign;

  const _MetricCell({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    this.negative = false,
    this.hero = false,
    this.sign,
  });

  @override
  Widget build(BuildContext context) {
    final prefix = sign ?? (negative ? '−' : '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: hero ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '$prefix${CurrencyFormatter.format(amount)}',
            style: TextStyle(
              fontSize: hero ? 14 : 12,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Duration badge ─────────────────────────────────────

class _DurationBadge extends StatelessWidget {
  final int minutes;
  const _DurationBadge({required this.minutes});

  @override
  Widget build(BuildContext context) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final label = h > 0 ? '${h}h ${m}m' : '${m}m';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ─────────────────────── Session status badge ────────────────────────────────

/// Badge de estado reutilizable también desde el detail page.
class SessionStatusBadge extends StatelessWidget {
  final CashSessionStatus status;
  const SessionStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      CashSessionStatus.open => ('Abierta', AppColors.success, Icons.lock_open),
      CashSessionStatus.closed => (
        'Cerrada',
        AppColors.primary,
        Icons.lock_outline,
      ),
      CashSessionStatus.voided => (
        'Anulada',
        AppColors.textSecondary,
        Icons.cancel_outlined,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
