import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../orders/presentation/models/sell_mode.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../printer_configs/data/printing_orchestrator.dart';
import '../../domain/entities/tab_session.dart';
import '../controllers/tab_session_detail_controller.dart';
import '../widgets/tab_payment_dialog.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final id = Get.parameters['id'] ?? Get.arguments?['id'] as String?;
      if (id == null) return;
      await controller.init(id);
      // Atajo "abrir y agregar el primer ticket de una": cuando llegamos
      // desde "Abrir cuenta libre" en OpenTabsPage, el operario espera
      // que la app ya esté lista para cobrar — no que tenga que tocar
      // "Agregar ticket" como paso extra. Si el caller pasó
      // `autoAddTicket=true`, saltamos directo al catálogo.
      final auto = Get.arguments?['autoAddTicket'] == true;
      if (!auto) return;
      final session = controller.session.value;
      if (session == null || !mounted) return;
      _onAddTicket(session);
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
        onTap: () => Navigator.of(context).pop(),
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => PrintingOrchestrator.printTabSessionReceiptManual(s),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          _StatusBadge(label: s.status.displayName, color: accent),
        ],
      ),
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
    // Para cuentas libres (sin mesa) la primera línea de `notes` es la
    // etiqueta de la cuenta — ya se muestra en el header, no tiene
    // sentido repetirla como bloque "Notas". Si hay líneas adicionales
    // las mostramos como notas reales.
    final showNotesCard = s.notes != null &&
        s.notes!.trim().isNotEmpty &&
        // Si tiene mesa, las notas son notas de verdad.
        (s.hasTable ||
            // Si NO tiene mesa, mostramos solo si hay más que una sola
            // línea (la 1ra es el label).
            s.notes!.contains('\n'));

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
          if (showNotesCard) ...[
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.25),
                width: 1.2,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.restaurant_menu,
                    color: AppColors.accent,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Lista para vender',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Aún no hay productos cargados.\nAgregá el primero para empezar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: controller.isMutating.value
                      ? null
                      : () => _onAddTicket(s),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    'Agregar primer producto',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
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
            onPressed: () => Navigator.of(context).pop(),
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
                // "Agregar" (no "Agregar ticket") para que NO envuelva a 2
                // líneas en el botón angosto y quede del mismo alto que el
                // de cobrar.
                label: const Text('Agregar', maxLines: 1),
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
                      // FittedBox: el monto puede ser largo ("$146.500") y
                      // no debe desbordar ni envolver — se achica si hace
                      // falta y queda en una línea.
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          s.paidAmount > 0.01
                              ? 'Cobrar restante ${CurrencyFormatter.format(s.balance)}'
                              : 'Procesar pago ${CurrencyFormatter.format(s.balance)}',
                          maxLines: 1,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
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
                        maxLines: 1,
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
    // Pasamos un `SellMode.tabSession` a la pantalla unificada — el
    // ticket nuevo se atará automáticamente a esta cuenta (mesa o
    // libre) y el pill mostrará "Cuenta: X" para que el operario
    // entienda dónde está parado.
    Get.toNamed(
      AppRoutes.sell,
      arguments: {
        'mode': SellMode.tabSession(
          sessionId: s.id,
          sessionLabel: s.displayLabel(),
          tableElementId: s.tableElementId,
          tableId: s.tableId,
          tableName: s.tableName,
        ),
      },
    )?.then((_) {
      // Volver a la cuenta: refrescamos para ver el ticket nuevo.
      controller.load();
    });
  }

  void _onPayTab(TabSession s) {
    // Se cobra IGUAL que una orden: un dialog en contexto (no una
    // pantalla aparte). Por debajo distribuye FIFO entre los tickets.
    showDialog<bool>(
      context: context,
      builder: (_) => TabPaymentDialog(session: s),
    ).then((paid) {
      if (paid == true) controller.load();
    });
  }

  Future<void> _confirmClose() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Cerrar cuenta'),
        content: const Text(
          'La cuenta quedará marcada como cerrada y no se podrán '
          'agregar más tickets ni pagos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Cerrar cuenta'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final ok = await controller.close();
      if (ok && mounted) Navigator.of(context).pop();
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
