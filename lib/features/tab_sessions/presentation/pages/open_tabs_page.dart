import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/tab_session.dart';
import '../controllers/open_tabs_controller.dart';

/// Vista de cuentas abiertas — el "estado del negocio en vivo":
///
/// - Cada card es una cuenta con su mesa/cliente, cantidad de tickets,
///   total, pagado y saldo pendiente. Card destaca con borde acento
///   si tiene saldo.
/// - Stats header: cuentas abiertas, tickets totales, saldo total
///   pendiente — el dueño ve de un vistazo cuánto le falta cobrar.
/// - Tap en una card → detalle de la cuenta (pago/cerrar/agregar
///   ticket).
class OpenTabsPage extends GetView<OpenTabsController> {
  const OpenTabsPage({super.key});

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
                    controller.sessions.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.sessions.isEmpty) {
                  return _buildEmptyState();
                }
                return RefreshIndicator(
                  onRefresh: controller.load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      _buildStatsBar(),
                      const SizedBox(height: 16),
                      ...controller.sessions.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TabCard(
                            session: s,
                            onTap: () => Get.toNamed(
                              AppRoutes.tabSessionDetail
                                  .replaceAll(':id', s.id),
                            )?.then((_) => controller.load()),
                          ),
                        ),
                      ),
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

  Widget _buildHeader() {
    return AppGradientHeader(
      title: 'Cuentas abiertas',
      subtitle: 'Mesas y deliveries activos en este momento',
      leading: GestureDetector(
        onTap: () => Get.back(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
      ),
      trailing: GestureDetector(
        onTap: controller.load,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.refresh, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              label: 'Cuentas',
              value: '${controller.sessions.length}',
              accent: AppColors.primary,
            ),
          ),
          Container(width: 1, height: 36, color: AppColors.divider),
          Expanded(
            child: _StatTile(
              label: 'Tickets',
              value: '${controller.totalTickets}',
              accent: AppColors.info,
            ),
          ),
          Container(width: 1, height: 36, color: AppColors.divider),
          Expanded(
            child: _StatTile(
              label: 'Pendiente',
              value: CurrencyFormatter.format(controller.totalPendingBalance),
              accent: controller.totalPendingBalance > 0
                  ? AppColors.error
                  : AppColors.success,
              valueSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin cuentas abiertas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Las mesas y pedidos activos aparecerán acá\nen tiempo real.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final double valueSize;

  const _StatTile({
    required this.label,
    required this.value,
    required this.accent,
    this.valueSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: valueSize,
            fontWeight: FontWeight.w800,
            color: accent,
            letterSpacing: -0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _TabCard extends StatelessWidget {
  final TabSession session;
  final VoidCallback onTap;

  const _TabCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasBalance = session.hasPendingBalance;
    final accent = hasBalance ? AppColors.primary : AppColors.success;

    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasBalance
                  ? accent.withValues(alpha: 0.5)
                  : AppColors.border,
              width: hasBalance ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  session.tableElementId != null ||
                          session.tableId != null
                      ? Icons.table_restaurant_outlined
                      : Icons.delivery_dining_outlined,
                  size: 22,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.displayLabel(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        '${session.totalOrders} ${session.totalOrders == 1 ? "ticket" : "tickets"}',
                        if (session.partySize != null &&
                            session.partySize! > 0)
                          '${session.partySize} pers.',
                        'desde ${DateFormat('HH:mm').format(session.openedAt)}',
                      ].join(' · '),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    CurrencyFormatter.format(session.totalAmount),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasBalance
                        ? 'Debe ${CurrencyFormatter.format(session.balance)}'
                        : 'Pagado',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: hasBalance
                          ? AppColors.error
                          : AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textHint,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
