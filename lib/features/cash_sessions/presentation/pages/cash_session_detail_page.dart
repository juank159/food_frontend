import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/cash_session.dart';
import '../controllers/cash_session_history_controller.dart';
import 'cash_session_history_page.dart' show SessionStatusBadge;

/// Reporte completo de una sesión de caja (X de caja parcial / Z de cierre).
///
/// Recibe la [CashSession] via `Get.arguments` (pasada desde la lista)
/// y carga el reporte detallado (pagos por método + lista de cobros cash)
/// usando el [CashSessionHistoryController] ya registrado.
class CashSessionDetailPage extends StatefulWidget {
  const CashSessionDetailPage({super.key});

  @override
  State<CashSessionDetailPage> createState() => _CashSessionDetailPageState();
}

class _CashSessionDetailPageState extends State<CashSessionDetailPage> {
  late final CashSessionHistoryController controller;
  CashSession? _session;

  CashSession get session => _session!;
  bool get _hasSession => _session != null;

  @override
  void initState() {
    super.initState();
    controller = Get.find<CashSessionHistoryController>();
    final args = Get.arguments;
    if (args is CashSession) {
      _session = args;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.loadReport(_session!.id);
      });
    } else {
      // Sin argumentos válidos (p.ej. deep-link directo) → volver atrás.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasSession) {
      return const Scaffold(body: SizedBox.shrink());
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final date = DateFormat('dd MMM yyyy', 'es').format(session.openedAt.toLocal());
    return AppGradientHeader(
      title: 'Sesión · $date',
      subtitle: _subtitleForSession(session),
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
        if (controller.isLoadingReport.value) {
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          );
        }
        return GestureDetector(
          onTap: () => controller.loadReport(session.id),
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
  }

  String _subtitleForSession(CashSession s) {
    final type = s.isClosed
        ? 'Z de caja'
        : s.isOpen
            ? 'X de caja (en curso)'
            : 'Sesión anulada';
    final dur = s.durationMinutes;
    if (dur != null) {
      final h = dur ~/ 60;
      final m = dur % 60;
      final durStr = h > 0 ? '${h}h ${m}m' : '${m}m';
      return '$type · $durStr';
    }
    return type;
  }

  // ── Cuerpo ──────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildStatusCard(),
        const SizedBox(height: 12),
        _buildStaffCard(),
        const SizedBox(height: 12),
        _buildCashBreakdownCard(),
        if (session.totalOtherCollected > 0 || session.totalCashExpenses > 0) ...[
          const SizedBox(height: 12),
          _buildSecondaryBreakdowns(),
        ],
        if (session.isClosed) ...[
          const SizedBox(height: 12),
          _buildCloseCard(),
        ],
        const SizedBox(height: 12),
        _buildReportSection(),
      ],
    );
  }

  // ── Estado de la sesión ──────────────────────────────────────────────────

  Widget _buildStatusCard() {
    final openedStr = DateFormat('dd MMM yyyy · HH:mm', 'es')
        .format(session.openedAt.toLocal());
    return _InfoCard(
      children: [
        Row(
          children: [
            SessionStatusBadge(status: session.status),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Apertura: $openedStr',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        if (session.closedAt != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.lock_outline,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Cierre: ${DateFormat('dd MMM yyyy · HH:mm', 'es').format(session.closedAt!.toLocal())}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
        if (session.notes != null && session.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.notes_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  session.notes!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Personal ─────────────────────────────────────────────────────────────

  Widget _buildStaffCard() {
    return _InfoCard(
      header: 'PERSONAL',
      headerIcon: Icons.badge_outlined,
      children: [
        _staffRow(
          label: 'Abrió',
          name: session.openedByName ?? 'Desconocido',
          icon: Icons.lock_open,
          color: AppColors.success,
        ),
        if (session.closedByName != null) ...[
          const SizedBox(height: 8),
          _staffRow(
            label: 'Cerró',
            name: session.closedByName!,
            icon: Icons.lock_outline,
            color: AppColors.primary,
          ),
        ],
      ],
    );
  }

  Widget _staffRow({
    required String label,
    required String name,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
            Text(name,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }

  // ── Desglose de efectivo ──────────────────────────────────────────────────

  Widget _buildCashBreakdownCard() {
    return _InfoCard(
      header: 'EFECTIVO',
      headerIcon: Icons.payments_outlined,
      children: [
        _amountRow(
          label: 'Fondo inicial',
          amount: session.openingAmount,
          icon: Icons.savings_outlined,
          color: AppColors.info,
        ),
        const _Divider(),
        _amountRow(
          label: 'Cobros en efectivo (${session.totalPaymentsCount})',
          amount: session.totalCashCollected,
          icon: Icons.add_circle_outline,
          color: AppColors.success,
        ),
        if (session.totalCashExpenses > 0) ...[
          const _Divider(),
          _amountRow(
            label: 'Gastos del turno',
            amount: session.totalCashExpenses,
            icon: Icons.remove_circle_outline,
            color: AppColors.error,
            prefix: '−',
          ),
        ],
        const _Divider(),
        _amountRow(
          label: session.isClosed ? 'Esperado al cierre' : 'Esperado en caja',
          amount: session.currentExpectedAmount,
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.primary,
          hero: true,
        ),
      ],
    );
  }

  // ── Otros métodos + gastos en fila ────────────────────────────────────────

  Widget _buildSecondaryBreakdowns() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (session.totalOtherCollected > 0)
          Expanded(
            child: _InfoCard(
              header: 'OTROS MÉTODOS',
              headerIcon: Icons.credit_card_outlined,
              headerColor: AppColors.info,
              children: [
                _amountRow(
                  label: '${session.totalOtherCount} cobros',
                  amount: session.totalOtherCollected,
                  icon: Icons.swap_horiz_outlined,
                  color: AppColors.info,
                  hero: true,
                ),
                const SizedBox(height: 4),
                const Text(
                  'No afecta el cuadre de caja física.',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
        if (session.totalOtherCollected > 0 && session.totalCashExpenses > 0)
          const SizedBox(width: 12),
        if (session.totalCashExpenses > 0)
          Expanded(
            child: _InfoCard(
              header: 'GASTOS',
              headerIcon: Icons.receipt_long_outlined,
              headerColor: AppColors.error,
              children: [
                _amountRow(
                  label: 'Total gastado',
                  amount: session.totalCashExpenses,
                  icon: Icons.money_off_outlined,
                  color: AppColors.error,
                  prefix: '−',
                  hero: true,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ya descontados del esperado.',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Cierre ──────────────────────────────────────────────────────────────

  Widget _buildCloseCard() {
    final diff = session.difference ?? 0;
    final isOk = diff.abs() <= 0.01;
    final isMissing = diff < 0;
    final color = isOk
        ? AppColors.success
        : (isMissing ? AppColors.error : AppColors.warning);
    final diffLabel = isOk
        ? 'Cuadre exacto'
        : (isMissing ? 'Faltante' : 'Sobrante');

    return _InfoCard(
      header: 'CIERRE',
      headerIcon: Icons.lock_outline,
      children: [
        _amountRow(
          label: 'Contado al cierre',
          amount: session.closingAmountCounted ?? 0,
          icon: Icons.calculate_outlined,
          color: AppColors.textPrimary,
        ),
        const _Divider(),
        _amountRow(
          label: diffLabel,
          amount: diff.abs(),
          icon: isOk
              ? Icons.check_circle_outline
              : (isMissing
                  ? Icons.error_outline
                  : Icons.warning_amber_rounded),
          color: color,
          prefix: isOk ? '=' : (isMissing ? '−' : '+'),
          hero: true,
        ),
        if (session.closingNotes != null &&
            session.closingNotes!.trim().isNotEmpty) ...[
          const _Divider(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.notes_outlined,
                  size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  session.closingNotes!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Sección de reporte (pagos detallados) ─────────────────────────────────

  Widget _buildReportSection() {
    return Obx(() {
      if (controller.isLoadingReport.value) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        );
      }

      final data = controller.reportData.value;
      if (data == null) {
        return GestureDetector(
          onTap: () => controller.loadReport(session.id),
          child: _InfoCard(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.refresh, size: 16, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'Cargar detalle de cobros',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }

      final byMethod = data['by_method'] as Map<String, dynamic>? ?? {};
      final cashPayments =
          (data['cash_payments'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Desglose por método
          if (byMethod.isNotEmpty) ...[
            _InfoCard(
              header: 'DESGLOSE POR MÉTODO',
              headerIcon: Icons.pie_chart_outline,
              children: byMethod.entries
                  .map((e) => _buildMethodRow(e.key, e.value))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          // Lista de cobros en efectivo
          if (cashPayments.isNotEmpty)
            _InfoCard(
              header: 'COBROS EN EFECTIVO (${cashPayments.length})',
              headerIcon: Icons.receipt_outlined,
              children: cashPayments
                  .map((p) => _CashPaymentRow(payment: p))
                  .toList(),
            ),
        ],
      );
    });
  }

  Widget _buildMethodRow(String method, dynamic data) {
    final map = data as Map<String, dynamic>? ?? {};
    final count = (map['count'] as num?)?.toInt() ?? 0;
    final total = _parseDouble(map['total']);
    final (label, icon, color) = _methodMeta(method);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$label ($count)',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
          Text(
            CurrencyFormatter.format(total),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  (String, IconData, Color) _methodMeta(String method) {
    switch (method) {
      case 'cash':
        return ('Efectivo', Icons.payments_outlined, AppColors.success);
      case 'card':
        return ('Tarjeta', Icons.credit_card, AppColors.info);
      case 'transfer':
        return ('Transferencia', Icons.account_balance_outlined, AppColors.primary);
      case 'digital_wallet':
        return ('Billetera digital', Icons.account_balance_wallet_outlined, AppColors.warning);
      default:
        return (method, Icons.attach_money, AppColors.textSecondary);
    }
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────

  Widget _amountRow({
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
    bool hero = false,
    String? prefix,
  }) {
    final sign = prefix ?? '';
    return Row(
      children: [
        Container(
          width: hero ? 38 : 30,
          height: hero ? 38 : 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(hero ? 10 : 8),
          ),
          child: Icon(icon, size: hero ? 18 : 15, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: hero ? 13 : 12,
              fontWeight: hero ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          '$sign${CurrencyFormatter.format(amount)}',
          style: TextStyle(
            fontSize: hero ? 18 : 14,
            fontWeight: FontWeight.w800,
            color: hero ? color : AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  double _parseDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

// ─────────────────────── Cash payment row ─────────────────────────────────────

class _CashPaymentRow extends StatelessWidget {
  final Map<String, dynamic> payment;
  const _CashPaymentRow({required this.payment});

  @override
  Widget build(BuildContext context) {
    final amount = _parse(payment['amount']);
    final orderNum = payment['order_number']?.toString() ?? '';
    final dateStr = payment['processed_at']?.toString();
    final time = dateStr != null
        ? DateFormat('HH:mm', 'es').format(DateTime.parse(dateStr).toLocal())
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.receipt_outlined,
                size: 15, color: AppColors.success),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orderNum.isNotEmpty ? 'Pedido #$orderNum' : 'Cobro',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textPrimary),
                ),
                if (time.isNotEmpty)
                  Text(time,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.format(amount),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  double _parse(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

// ─────────────────────── Info card ───────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String? header;
  final IconData? headerIcon;
  final Color? headerColor;
  final List<Widget> children;

  const _InfoCard({
    this.header,
    this.headerIcon,
    this.headerColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
          if (header != null) ...[
            Row(
              children: [
                if (headerIcon != null)
                  Icon(headerIcon,
                      size: 13,
                      color: headerColor ?? AppColors.textSecondary),
                if (headerIcon != null) const SizedBox(width: 5),
                Text(
                  header!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: headerColor ?? AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, color: AppColors.divider),
    );
  }
}
