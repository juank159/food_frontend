import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/constants/reservation_enums.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/reservation.dart';
import '../controllers/reservations_controller.dart';

/// Reservations Page — listado principal de reservaciones.
///
/// Mismo lenguaje visual que `OrdersPage` y `CustomersPage`:
///   - Header gradient con KPIs (Próximas / Hoy / Confirmadas / Pendientes).
///   - Filtros inline con `AppFilterChip`.
///   - Cards con stripe vertical de color por status.
///   - Pull-to-refresh + empty / error states unificados.
class ReservationsPage extends GetView<ReservationsController> {
  const ReservationsPage({super.key});

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
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
      bottomNavigationBar: AppPrimaryActionBar(
        label: 'Nueva reserva',
        icon: Icons.event_available,
        onPressed: () async {
          final result = await Get.toNamed(AppRoutes.createReservation);
          if (result != null) controller.refreshAll();
        },
      ),
    );
  }

  // ─────────────────────────── Header ───────────────────────────

  Widget _buildHeader() {
    return Obx(() {
      return AppGradientHeader(
        title: 'Reservaciones',
        subtitle: 'Reservas y disponibilidad',
        leading: GestureDetector(
          onTap: () => Get.back<void>(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        chips: [
          AppKpiChip(
            icon: Icons.event_available_outlined,
            label: 'Próximas',
            value: controller.upcomingCount.toString(),
          ),
          AppKpiChip(
            icon: Icons.today_outlined,
            label: 'Hoy',
            value: controller.todayCount.toString(),
          ),
          AppKpiChip(
            icon: Icons.verified_outlined,
            label: 'Confirmadas',
            value: controller.confirmedCount.toString(),
          ),
          AppKpiChip(
            icon: Icons.hourglass_top_outlined,
            label: 'Pendientes',
            value: controller.pendingCount.toString(),
          ),
        ],
      );
    });
  }

  // ─────────────────────────── Filters ───────────────────────────

  Widget _buildFilters() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: SizedBox(
        height: 40,
        child: Obx(() {
          final selected = controller.filter.value;
          return ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final f in ReservationListFilter.values)
                AppFilterChip(
                  label: f.label,
                  selected: selected == f,
                  onTap: () => controller.setFilter(f),
                  icon: _filterIcon(f),
                ),
            ],
          );
        }),
      ),
    );
  }

  IconData _filterIcon(ReservationListFilter f) {
    switch (f) {
      case ReservationListFilter.all:
        return Icons.apps;
      case ReservationListFilter.upcoming:
        return Icons.event_available_outlined;
      case ReservationListFilter.today:
        return Icons.today_outlined;
      case ReservationListFilter.pending:
        return Icons.hourglass_top_outlined;
      case ReservationListFilter.confirmed:
        return Icons.verified_outlined;
    }
  }

  // ─────────────────────────── Body ───────────────────────────

  Widget _buildBody(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && !controller.hasReservations) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.errorMessage.value.isNotEmpty &&
          !controller.hasReservations) {
        return AppErrorState(
          message: controller.errorMessage.value,
          onRetry: controller.refreshAll,
        );
      }
      if (!controller.hasReservations) {
        final hasFilter = controller.filter.value != ReservationListFilter.all;
        return AppEmptyState(
          icon: Icons.event_outlined,
          title: hasFilter ? 'Sin resultados' : 'Aún no hay reservas',
          message: hasFilter
              ? 'Probá con otro filtro para ver más reservaciones.'
              : 'Empezá agendando la primera reserva del día.',
          actionLabel: hasFilter ? 'Ver todas' : 'Nueva reserva',
          actionIcon:
              hasFilter ? Icons.clear_all : Icons.event_available_outlined,
          onAction: () async {
            if (hasFilter) {
              controller.setFilter(ReservationListFilter.all);
            } else {
              final result = await Get.toNamed(AppRoutes.createReservation);
              if (result != null) controller.refreshAll();
            }
          },
        );
      }
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: controller.refreshAll,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: controller.reservations.length,
          itemBuilder: (context, index) {
            final r = controller.reservations[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReservationCard(
                reservation: r,
                onTap: () => _onReservationTap(r),
                onDelete: () => _confirmDelete(context, r),
              ),
            );
          },
        ),
      );
    });
  }

  Future<void> _onReservationTap(Reservation r) async {
    final result = await Get.toNamed<dynamic>(
      AppRoutes.buildReservationDetail(r.id),
    );
    if (result != null) controller.refreshAll();
  }

  Future<void> _confirmDelete(BuildContext context, Reservation r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar reserva'),
        content: Text(
          '¿Seguro querés eliminar la reserva de ${r.customerName}? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.deleteReservation(r.id);
    }
  }
}

// ─────────────────────────── Helpers de estilo (compartidos) ───────────────────────────

/// Color asociado a cada `ReservationStatus`. Mantiene el lenguaje visual
/// del módulo de órdenes (warning/info/primary/success/error/secondary).
Color reservationStatusColor(ReservationStatus status) {
  switch (status) {
    case ReservationStatus.pending:
      return AppColors.warning;
    case ReservationStatus.confirmed:
      return AppColors.info;
    case ReservationStatus.seated:
      return AppColors.primary;
    case ReservationStatus.completed:
      return AppColors.success;
    case ReservationStatus.noShow:
      return AppColors.error;
    case ReservationStatus.cancelled:
      return AppColors.textSecondary;
  }
}

IconData reservationStatusIcon(ReservationStatus status) {
  switch (status) {
    case ReservationStatus.pending:
      return Icons.hourglass_top_outlined;
    case ReservationStatus.confirmed:
      return Icons.verified_outlined;
    case ReservationStatus.seated:
      return Icons.event_seat_outlined;
    case ReservationStatus.completed:
      return Icons.check_circle_outline;
    case ReservationStatus.noShow:
      return Icons.person_off_outlined;
    case ReservationStatus.cancelled:
      return Icons.cancel_outlined;
  }
}

/// Devuelve un texto relativo amigable para una reserva ("en 2h",
/// "mañana 8pm", "vencida hace 1d").
String formatReservationWhen(Reservation r) {
  final now = DateTime.now();
  final diff = r.reservedFor.difference(now);

  if (r.isTerminal) {
    // Para reservas finalizadas, mostramos sólo la fecha en formato corto.
    return _formatDateTime(r.reservedFor);
  }

  if (diff.isNegative) {
    final past = -diff.inMinutes;
    if (past < 60) return 'vencida hace ${past}m';
    if (past < 1440) return 'vencida hace ${past ~/ 60}h';
    return 'vencida hace ${past ~/ 1440}d';
  }

  if (diff.inMinutes < 60) {
    return 'en ${diff.inMinutes}m';
  }
  if (r.isToday) {
    return 'hoy ${_formatTime(r.reservedFor)}';
  }
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  if (r.reservedFor.year == tomorrow.year &&
      r.reservedFor.month == tomorrow.month &&
      r.reservedFor.day == tomorrow.day) {
    return 'mañana ${_formatTime(r.reservedFor)}';
  }
  if (diff.inDays < 7) {
    return 'en ${diff.inDays}d ${_formatTime(r.reservedFor)}';
  }
  return _formatDateTime(r.reservedFor);
}

String _formatDateTime(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year} ${_formatTime(d)}';
}

String _formatTime(DateTime d) {
  final hour = d.hour.toString().padLeft(2, '0');
  final minute = d.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

// ─────────────────────────── Reservation Card ───────────────────────────

/// Card de reservación — stripe lateral, avatar tintado, info principal y
/// chips compactos. Misma anatomía que `OrderCard` y `CustomerCard`.
class _ReservationCard extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ReservationCard({
    required this.reservation,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final accent = reservationStatusColor(reservation.status);
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(accent),
                        const SizedBox(height: 10),
                        _buildChipsRow(),
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

  Widget _buildHeader(Color accent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            reservation.initials,
            style: TextStyle(
              color: accent,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reservation.customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 12,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      formatReservationWhen(reservation),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: reservation.isOverdue
                            ? AppColors.error
                            : AppColors.textSecondary,
                        fontWeight: reservation.isOverdue
                            ? FontWeight.w700
                            : FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _StatusPill(status: reservation.status, color: accent),
        const SizedBox(width: 4),
        _buildMenu(),
      ],
    );
  }

  Widget _buildMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Más opciones',
      icon: const Icon(
        Icons.more_vert,
        size: 18,
        color: AppColors.textSecondary,
      ),
      onSelected: (value) {
        if (value == 'delete') onDelete();
      },
      itemBuilder: (_) => const [
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: AppColors.error),
              SizedBox(width: 8),
              Text('Eliminar', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChipsRow() {
    final chips = <Widget>[
      _MiniInfo(
        icon: Icons.group_outlined,
        label:
            '${reservation.partySize} ${reservation.partySize == 1 ? "persona" : "personas"}',
      ),
      _MiniInfo(
        icon: Icons.schedule,
        label: '${reservation.durationMinutes} min',
      ),
      if (reservation.hasTable)
        _MiniInfo(
          icon: Icons.table_restaurant_outlined,
          label: 'Mesa ${reservation.tableElementId}',
        ),
      if (reservation.customerPhone != null &&
          reservation.customerPhone!.isNotEmpty)
        _MiniInfo(
          icon: Icons.phone_outlined,
          label: reservation.customerPhone!,
        ),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips,
    );
  }
}

/// Pill de estado con punto + texto. Mismo look que el de `OrderCard`.
class _StatusPill extends StatelessWidget {
  final ReservationStatus status;
  final Color color;

  const _StatusPill({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.displayName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniInfo({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
