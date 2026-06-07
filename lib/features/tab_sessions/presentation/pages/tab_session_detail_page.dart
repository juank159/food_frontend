import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/tab_session.dart';
import '../controllers/tab_session_detail_controller.dart';
import '../widgets/tab_ticket_card.dart';

/// Pantalla principal de una cuenta abierta. Muestra:
/// - Header con totales rolled-up (subtotal, taxes, propina, total,
///   pagado, balance) + estado + datos del cliente/mesa.
/// - Lista de tickets (orders) que componen la cuenta.
/// - Acciones: agregar ticket, cobrar cuenta, cerrar/anular.
class TabSessionDetailPage extends StatefulWidget {
  const TabSessionDetailPage({super.key});

  @override
  State<TabSessionDetailPage> createState() => _TabSessionDetailPageState();
}

class _TabSessionDetailPageState extends State<TabSessionDetailPage> {
  late final TabSessionDetailController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<TabSessionDetailController>();
    // Diferir al próximo frame para que `setState` no ocurra durante
    // build (memoria feedback_initstate_async).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = Get.parameters['id'] ?? Get.arguments?['id'] as String?;
      if (id != null) controller.init(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Obx(() {
          if (controller.isLoading.value && controller.session.value == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final s = controller.session.value;
          if (s == null) {
            return Center(
              child: AppErrorState(
                title: 'No se pudo cargar la cuenta',
                message: controller.errorMessage.value.isEmpty
                    ? 'Intentá refrescar'
                    : controller.errorMessage.value,
                onRetry: controller.load,
              ),
            );
          }
          return Column(
            children: [
              _buildHeader(s),
              Expanded(child: _buildBody(s)),
            ],
          );
        }),
      ),
      bottomNavigationBar: Obx(() {
        final s = controller.session.value;
        if (s == null) return const SizedBox.shrink();
        return _buildBottomBar(s);
      }),
    );
  }

  // ──────────────────────────── Header ────────────────────────────

  Widget _buildHeader(TabSession s) {
    final accent = _statusColor(s.status);
    return AppGradientHeader(
      title: s.displayLabel(),
      subtitle: _headerSubtitle(s),
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
      trailing: _StatusBadge(label: s.status.displayName, color: accent),
    );
  }

  String _headerSubtitle(TabSession s) {
    final parts = <String>[];
    parts.add('${s.totalOrders} tickets');
    parts.add('Abierta ${DateFormat('HH:mm').format(s.openedAt)}');
    if (s.partySize != null && s.partySize! > 0) {
      parts.add('${s.partySize} personas');
    }
    return parts.join(' · ');
  }

  Color _statusColor(TabSessionStatus status) {
    switch (status) {
      case TabSessionStatus.open:
        return AppColors.success;
      case TabSessionStatus.settling:
        return AppColors.warning;
      case TabSessionStatus.closed:
        return AppColors.textSecondary;
      case TabSessionStatus.voided:
        return AppColors.error;
    }
  }

  // ─────────────────────────── Body ────────────────────────────

  Widget _buildBody(TabSession s) {
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _buildTotalsCard(s),
          const SizedBox(height: 16),
          if (s.customerName != null && s.customerName!.isNotEmpty) ...[
            _buildCustomerCard(s),
            const SizedBox(height: 16),
          ],
          _buildTicketsSection(s),
          if (s.notes != null && s.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildNotesCard(s),
          ],
        ],
      ),
    );
  }

  Widget _buildTotalsCard(TabSession s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _totalRow('Subtotal', s.subtotal),
          if (s.taxAmount > 0) _totalRow('Impuestos', s.taxAmount),
          if (s.discountAmount > 0)
            _totalRow('Descuento', -s.discountAmount, color: AppColors.success),
          if (s.tipAmount > 0) _totalRow('Propina', s.tipAmount),
          if (s.deliveryFee > 0) _totalRow('Envío', s.deliveryFee),
          const Divider(height: 20),
          _totalRow('Total', s.totalAmount, isBold: true),
          const SizedBox(height: 4),
          _totalRow('Pagado', s.paidAmount, color: AppColors.success),
          const SizedBox(height: 4),
          _totalRow(
            'Saldo pendiente',
            s.balance,
            isBold: true,
            color: s.balance > 0.01 ? AppColors.error : AppColors.success,
            fontSize: 18,
          ),
        ],
      ),
    );
  }

  Widget _totalRow(
    String label,
    double amount, {
    bool isBold = false,
    Color? color,
    double fontSize = 14,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
              color: color ?? AppColors.textPrimary,
            ),
          ),
          Text(
            CurrencyFormatter.format(amount),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
              color: color ?? AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(TabSession s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.person, size: 18, color: AppColors.info),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.customerName!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Cliente titular',
                  style: TextStyle(
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

  Widget _buildTicketsSection(TabSession s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Tickets',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${s.totalOrders}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (s.orders.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: const Text(
              'No hay tickets en esta cuenta',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          )
        else
          ...s.orders.map(
            (rawOrder) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TabTicketCard(rawOrder: rawOrder as Map<String, dynamic>),
            ),
          ),
      ],
    );
  }

  Widget _buildNotesCard(TabSession s) {
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
            'Notas',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.notes!,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── Bottom Bar ──────────────────────────

  Widget _buildBottomBar(TabSession s) {
    if (s.isClosed || s.isVoided) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Volver'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.isMutating.value
                    ? null
                    : () => _onAddTicket(s),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar ticket'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: s.hasPendingBalance
                  ? FilledButton.icon(
                      onPressed: controller.isMutating.value
                          ? null
                          : () => _onPayTab(s),
                      icon: const Icon(Icons.payments, size: 18),
                      label: Text(
                        'Cobrar ${CurrencyFormatter.format(s.balance)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: controller.isMutating.value
                          ? null
                          : _confirmClose,
                      icon: const Icon(Icons.lock_outline, size: 18),
                      label: const Text(
                        'Cerrar cuenta',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── Acciones ───────────────────────────

  void _onAddTicket(TabSession s) {
    // Pre-selecciona la mesa de la sesión para que el create_order
    // page la mantenga seleccionada y la nueva orden caiga en la
    // misma cuenta automáticamente (vía ensureSessionForOrder en backend).
    //
    // OJO: el create_order_page recibe `fromTabSession` (no
    // `fromTableService`) — esa rama del handler permite pre-seleccionar
    // la mesa solo con `tableElementId` (el `tableId` legacy puede ser
    // null) y deja al operario cambiar el tipo de orden si quiere
    // agregar un takeaway/delivery a la cuenta.
    Get.toNamed(
      AppRoutes.createOrder,
      arguments: {
        'fromTabSession': s.id,
        if (s.tableElementId != null) 'tableElementId': s.tableElementId,
        if (s.tableName != null) 'tableName': s.tableName,
        if (s.tableId != null) 'tableId': s.tableId,
      },
    )?.then((_) {
      // Volver a la cuenta: refrescamos para ver el ticket nuevo.
      controller.load();
    });
  }

  void _onPayTab(TabSession s) {
    Get.toNamed(
      '/tab-sessions/${s.id}/pay',
      arguments: {'session': s},
    )?.then((_) => controller.load());
  }

  Future<void> _confirmClose() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Cerrar cuenta'),
        content: const Text(
          'La cuenta quedará marcada como cerrada y no se podrán '
          'agregar más tickets ni pagos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Cerrar cuenta'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final ok = await controller.close();
      if (ok) Get.back();
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
