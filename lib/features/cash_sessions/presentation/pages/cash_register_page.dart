import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/cash_session.dart';
import '../controllers/cash_session_controller.dart';
import '../widgets/close_cash_dialog.dart';
import '../widgets/open_cash_dialog.dart';

/// Pantalla central de caja registradora.
///
/// Tres estados principales:
///   1. **Sin caja** (currentSession=null, lastClosed=null) → empty
///      state con CTA "Abrir caja".
///   2. **Resumen de cierre reciente** (lastClosed != null) → snapshot
///      del cierre con la diferencia, opción de empezar nueva.
///   3. **Caja abierta** (currentSession != null) → dashboard con
///      rollups en vivo + botón "Cerrar caja".
class CashRegisterPage extends GetView<CashSessionController> {
  const CashRegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value &&
                    controller.currentSession.value == null &&
                    controller.lastClosed.value == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final session = controller.currentSession.value;
                final lastClosed = controller.lastClosed.value;

                if (lastClosed != null) {
                  return _ClosedSummary(
                    session: lastClosed,
                    onDismiss: controller.dismissLastClosed,
                  );
                }
                if (session != null) {
                  return _ActiveSession(
                    session: session,
                    onClose: () => _showCloseDialog(session),
                    onRefresh: controller.reloadCurrent,
                  );
                }
                return _EmptyState(
                  onOpen: () => _showOpenDialog(),
                  onRefresh: controller.reloadCurrent,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AppGradientHeader(
      title: 'Caja',
      subtitle: 'Apertura, cierre y conciliación',
      leading: GestureDetector(
        onTap: () => Get.back(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: 20,
          ),
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
          onTap: controller.reloadCurrent,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.refresh,
              color: Colors.white,
              size: 20,
            ),
          ),
        );
      }),
    );
  }

  void _showOpenDialog() {
    Get.dialog(const OpenCashDialog(), barrierDismissible: false);
  }

  void _showCloseDialog(CashSession session) {
    Get.dialog(
      CloseCashDialog(session: session),
      barrierDismissible: false,
    );
  }
}

// ─────────────────────────── Empty state ───────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onOpen;
  final Future<void> Function() onRefresh;

  const _EmptyState({required this.onOpen, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.point_of_sale,
                size: 38,
                color: AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No hay caja abierta',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Para registrar cobros en efectivo necesitás abrir caja primero. '
              'Te vamos a pedir el efectivo con el que arrancás.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.lock_open, size: 20),
              label: const Text(
                'Abrir caja',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Active session ───────────────────────────

class _ActiveSession extends StatelessWidget {
  final CashSession session;
  final VoidCallback onClose;
  final Future<void> Function() onRefresh;

  const _ActiveSession({
    required this.session,
    required this.onClose,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        return ListView(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 32 : 16,
            vertical: 20,
          ),
          children: [
            _buildStatusBanner(),
            const SizedBox(height: 16),
            _buildKpiCard(),
            const SizedBox(height: 16),
            _buildDetailsCard(),
            const SizedBox(height: 24),
            _buildCloseButton(),
            const SizedBox(height: 8),
          ],
        );
      }),
    );
  }

  Widget _buildStatusBanner() {
    final opened = DateFormat('dd MMM yyyy · HH:mm').format(session.openedAt);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lock_open,
              color: AppColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Caja abierta',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Desde $opened${session.openedByName != null ? " · ${session.openedByName}" : ""}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard() {
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
        children: [
          _kpiRow(
            label: 'Fondo inicial',
            value: session.openingAmount,
            icon: Icons.savings_outlined,
            accent: AppColors.info,
          ),
          const Divider(height: 18, color: AppColors.divider),
          _kpiRow(
            label: 'Cobros en efectivo (${session.totalPaymentsCount})',
            value: session.totalCashCollected,
            icon: Icons.payments_outlined,
            accent: AppColors.success,
          ),
          const Divider(height: 18, color: AppColors.divider),
          _kpiRow(
            label: 'Esperado en caja',
            value: session.currentExpectedAmount,
            icon: Icons.account_balance_wallet_outlined,
            accent: AppColors.primary,
            isHero: true,
          ),
        ],
      ),
    );
  }

  Widget _kpiRow({
    required String label,
    required double value,
    required IconData icon,
    required Color accent,
    bool isHero = false,
  }) {
    return Row(
      children: [
        Container(
          width: isHero ? 44 : 36,
          height: isHero ? 44 : 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accent, size: isHero ? 22 : 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isHero ? 14 : 13,
              fontWeight: isHero ? FontWeight.w800 : FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          CurrencyFormatter.format(value),
          style: TextStyle(
            fontSize: isHero ? 22 : 16,
            fontWeight: FontWeight.w800,
            color: isHero ? accent : AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsCard() {
    if (session.notes == null || session.notes!.trim().isEmpty) {
      return const SizedBox.shrink();
    }
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
            'NOTAS DE APERTURA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            session.notes!,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onClose,
        icon: const Icon(Icons.lock_outline, size: 20),
        label: const Text(
          'Cerrar caja',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Closed summary ───────────────────────────

class _ClosedSummary extends StatelessWidget {
  final CashSession session;
  final VoidCallback onDismiss;

  const _ClosedSummary({required this.session, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final diff = session.difference ?? 0;
    final isOk = diff.abs() <= 0.01;
    final isMissing = diff < 0;
    final color = isOk
        ? AppColors.success
        : (isMissing ? AppColors.error : AppColors.warning);
    final label = isOk
        ? '¡Cuadre exacto!'
        : (isMissing ? 'Cerrada con faltante' : 'Cerrada con sobrante');

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 900;
      return ListView(
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 32 : 16,
          vertical: 24,
        ),
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                isOk
                    ? Icons.check_circle
                    : (isMissing
                        ? Icons.error_outline
                        : Icons.warning_amber_rounded),
                size: 40,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _summaryRow('Fondo inicial', session.openingAmount),
                _summaryRow(
                  'Cobros en efectivo (${session.totalPaymentsCount})',
                  session.totalCashCollected,
                ),
                const Divider(height: 16),
                _summaryRow(
                  'Esperado en caja',
                  session.expectedAmount ?? 0,
                  bold: true,
                ),
                _summaryRow(
                  'Contado al cierre',
                  session.closingAmountCounted ?? 0,
                  bold: true,
                ),
                const Divider(height: 16),
                _summaryRow(
                  'Diferencia',
                  diff,
                  bold: true,
                  color: color,
                  showSign: true,
                ),
              ],
            ),
          ),
          if (session.closingNotes != null &&
              session.closingNotes!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
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
                    'NOTAS DE CIERRE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    session.closingNotes!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onDismiss,
            icon: const Icon(Icons.refresh),
            label: const Text('Listo'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      );
    });
  }

  Widget _summaryRow(
    String label,
    double value, {
    bool bold = false,
    Color? color,
    bool showSign = false,
  }) {
    final prefix = showSign && value >= 0 ? '+' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: bold ? 14 : 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: color ?? AppColors.textPrimary,
            ),
          ),
          Text(
            '$prefix${CurrencyFormatter.format(value)}',
            style: TextStyle(
              fontSize: bold ? 16 : 14,
              fontWeight: FontWeight.w800,
              color: color ?? AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
