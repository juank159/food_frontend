import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../core/config/constants/reservation_enums.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/reservation.dart';
import '../controllers/reservation_detail_controller.dart';
import 'reservations_page.dart' show formatReservationWhen, reservationStatusColor, reservationStatusIcon;

/// Reservation Detail Page — pantalla de detalle de reserva.
///
/// Estructura:
///   - `AppGradientHeader` con el nombre del cliente, status y countdown.
///   - Hero con fecha/hora reservada y "en X horas / hace X horas".
///   - Sección "Cliente" con nombre, teléfono y email + CTAs (copy phone/email).
///   - Sección "Detalles" con party size, duración, mesa, notas.
///   - Sección "Acciones" con botones según las transiciones válidas.
///   - Acción discreta para eliminar la reserva.
class ReservationDetailPage extends GetView<ReservationDetailController> {
  const ReservationDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Obx(() {
          if (controller.isLoading) {
            return Column(
              children: [
                _buildSkeletonHeader(),
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }
          if (controller.hasError) {
            return Column(
              children: [
                _buildSkeletonHeader(),
                Expanded(
                  child: AppErrorState(
                    message: controller.errorMessage.value,
                    onRetry: controller.refreshAll,
                  ),
                ),
              ],
            );
          }
          final reservation = controller.reservation.value;
          if (reservation == null) return const SizedBox.shrink();
          return _buildLoaded(context, reservation);
        }),
      ),
      bottomNavigationBar: Obx(() {
        if (!controller.isLoaded) return const SizedBox.shrink();
        final r = controller.reservation.value!;
        if (r.isTerminal) return const SizedBox.shrink();
        return AppPrimaryActionBar(
          label: 'Editar reserva',
          icon: Icons.edit_outlined,
          onPressed: () => _onEdit(r),
        );
      }),
    );
  }

  // ─────────────────────────── Header ───────────────────────────

  Widget _buildSkeletonHeader() {
    return AppGradientHeader(
      title: 'Reserva',
      subtitle: 'Cargando detalle…',
      leading: _BackButton(),
    );
  }

  Widget _buildHeader(Reservation r) {
    final statusColor = reservationStatusColor(r.status);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor,
            Color.alphaBlend(
              Colors.black.withValues(alpha: 0.18),
              statusColor,
            ),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _BackButton(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reserva #${r.id.substring(0, r.id.length.clamp(0, 8))}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: r.status),
            ],
          ),
          const SizedBox(height: 14),
          _buildHeroCard(r),
        ],
      ),
    );
  }

  Widget _buildHeroCard(Reservation r) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              reservationStatusIcon(r.status),
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatFullDateTime(r.reservedFor),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _countdownText(r),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _countdownText(Reservation r) {
    if (r.isTerminal) return r.status.displayName;
    final friendly = formatReservationWhen(r);
    if (r.isOverdue) return friendly;
    if (r.isPast) return friendly;
    return 'Llega $friendly';
  }

  // ─────────────────────────── Body ───────────────────────────

  Widget _buildLoaded(BuildContext context, Reservation r) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: controller.refreshAll,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(r),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCustomerSection(context, r),
                const SizedBox(height: 16),
                _buildDetailsSection(r),
                const SizedBox(height: 16),
                _buildActionsSection(context, r),
                const SizedBox(height: 16),
                _buildDangerZone(context, r),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── Customer ───────────────────────────

  Widget _buildCustomerSection(BuildContext context, Reservation r) {
    return _DetailSection(
      title: 'Cliente',
      icon: Icons.person_outline,
      accent: AppColors.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(
            icon: Icons.badge_outlined,
            label: 'Nombre',
            value: r.customerName,
          ),
          if (r.customerPhone != null && r.customerPhone!.isNotEmpty) ...[
            const Divider(height: 16, color: AppColors.divider),
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Teléfono',
              value: r.customerPhone!,
              actionIcon: Icons.copy_outlined,
              actionTooltip: 'Copiar teléfono',
              onAction: () => _copyToClipboard(
                context,
                r.customerPhone!,
                label: 'Teléfono copiado',
              ),
            ),
          ],
          if (r.customerEmail != null && r.customerEmail!.isNotEmpty) ...[
            const Divider(height: 16, color: AppColors.divider),
            _InfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: r.customerEmail!,
              actionIcon: Icons.copy_outlined,
              actionTooltip: 'Copiar email',
              onAction: () => _copyToClipboard(
                context,
                r.customerEmail!,
                label: 'Email copiado',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _copyToClipboard(
    BuildContext context,
    String value, {
    required String label,
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(label),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─────────────────────────── Details ───────────────────────────

  Widget _buildDetailsSection(Reservation r) {
    return _DetailSection(
      title: 'Detalles',
      icon: Icons.event_outlined,
      accent: AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(
            icon: Icons.group_outlined,
            label: 'Personas',
            value:
                '${r.partySize} ${r.partySize == 1 ? "persona" : "personas"}',
          ),
          const Divider(height: 16, color: AppColors.divider),
          _InfoRow(
            icon: Icons.schedule,
            label: 'Duración estimada',
            value: '${r.durationMinutes} min',
          ),
          const Divider(height: 16, color: AppColors.divider),
          _InfoRow(
            icon: Icons.table_restaurant_outlined,
            label: 'Mesa',
            value: r.hasTable ? 'Mesa ${r.tableElementId}' : 'Sin asignar',
          ),
          if (r.notes != null && r.notes!.isNotEmpty) ...[
            const Divider(height: 16, color: AppColors.divider),
            _InfoRow(
              icon: Icons.sticky_note_2_outlined,
              label: 'Notas',
              value: r.notes!,
              multiline: true,
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────── Acciones ───────────────────────────

  Widget _buildActionsSection(BuildContext context, Reservation r) {
    final transitions = r.status.nextTransitions;
    if (transitions.isEmpty) {
      return _DetailSection(
        title: 'Acciones',
        icon: Icons.lock_outline,
        accent: AppColors.textSecondary,
        child: _InlineEmpty(
          icon: Icons.do_not_disturb_on_outlined,
          message:
              'Esta reserva está en un estado terminal y no admite más cambios.',
        ),
      );
    }
    return _DetailSection(
      title: 'Acciones',
      icon: Icons.bolt_outlined,
      accent: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < transitions.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Obx(() {
              final loading = controller.isMutating.value;
              return _ActionButton(
                status: transitions[i],
                loading: loading,
                onTap: loading
                    ? null
                    : () => _handleTransition(context, transitions[i]),
              );
            }),
          ],
        ],
      ),
    );
  }

  Future<void> _handleTransition(
    BuildContext context,
    ReservationStatus newStatus,
  ) async {
    if (newStatus == ReservationStatus.cancelled) {
      // Para cancelaciones pedimos razón opcional usando un dialog específico.
      final reason = await _askCancellationReason(context);
      if (reason == null) return; // usuario abortó
      await controller.cancel(reason: reason.isEmpty ? null : reason);
      return;
    }

    final confirmed = await _confirmTransition(context, newStatus);
    if (confirmed != true) return;
    await controller.changeStatus(newStatus);
  }

  Future<bool?> _confirmTransition(
    BuildContext context,
    ReservationStatus target,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_actionLabelFor(target)),
        content: Text(
          _actionDescriptionFor(target),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: reservationStatusColor(target),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<String?> _askCancellationReason(BuildContext context) async {
    final controllerText = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar reserva'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '¿Querés agregar una razón? Es opcional pero ayuda a llevar registro.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controllerText,
              decoration: appInputDecoration(
                label: 'Razón (opcional)',
                hint: 'Ej: el cliente llamó para reprogramar',
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () =>
                Navigator.of(ctx).pop(controllerText.text.trim()),
            child: const Text('Cancelar reserva'),
          ),
        ],
      ),
    );
    controllerText.dispose();
    return result;
  }

  String _actionLabelFor(ReservationStatus target) {
    switch (target) {
      case ReservationStatus.confirmed:
        return 'Confirmar reserva';
      case ReservationStatus.seated:
        return 'Sentar al cliente';
      case ReservationStatus.completed:
        return 'Completar reserva';
      case ReservationStatus.noShow:
        return 'Marcar como no presentado';
      case ReservationStatus.cancelled:
        return 'Cancelar reserva';
      case ReservationStatus.pending:
        return 'Volver a pendiente';
    }
  }

  String _actionDescriptionFor(ReservationStatus target) {
    switch (target) {
      case ReservationStatus.confirmed:
        return '¿Confirmás la reserva del cliente? Se notificará al equipo.';
      case ReservationStatus.seated:
        return '¿El cliente ya está en la mesa? Marcaremos la reserva como sentada.';
      case ReservationStatus.completed:
        return '¿La reserva ya terminó? Pasará al historial como completada.';
      case ReservationStatus.noShow:
        return '¿El cliente no se presentó? Quedará registrado como no-show.';
      case ReservationStatus.cancelled:
        return 'Vas a cancelar esta reserva.';
      case ReservationStatus.pending:
        return '¿Querés volver al estado pendiente?';
    }
  }

  // ─────────────────────────── Danger Zone ───────────────────────────

  Widget _buildDangerZone(BuildContext context, Reservation r) {
    return _DetailSection(
      title: 'Zona de riesgo',
      icon: Icons.warning_amber_outlined,
      accent: AppColors.error,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Eliminar la reserva la archivará. No se puede deshacer desde la app.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: 'Eliminar reserva',
            child: Material(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _confirmDelete(context, r),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
      final ok = await controller.delete();
      if (ok) Get.back<dynamic>(result: 'deleted');
    }
  }

  // ─────────────────────────── Edit ───────────────────────────

  Future<void> _onEdit(Reservation r) async {
    final result = await Get.toNamed(
      AppRoutes.buildEditReservation(r.id),
      arguments: r,
    );
    if (result != null) controller.refreshAll();
  }

  // ─────────────────────────── Helpers ───────────────────────────

  static String _formatFullDateTime(DateTime d) {
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year} · $hour:$minute';
  }
}

// ─────────────────────────── Sub-widgets ───────────────────────────

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ReservationStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? accent;
  final Widget child;

  const _DetailSection({
    required this.title,
    required this.icon,
    this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.primary;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool multiline;
  final IconData? actionIcon;
  final String? actionTooltip;
  final VoidCallback? onAction;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.multiline = false,
    this.actionIcon,
    this.actionTooltip,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: multiline ? 5 : 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        if (actionIcon != null && onAction != null) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: actionTooltip ?? '',
            child: Material(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onAction,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    actionIcon,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final ReservationStatus status;
  final bool loading;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.status,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = reservationStatusColor(status);
    final icon = reservationStatusIcon(status);
    final label = _labelFor(status);
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              if (loading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Icon(Icons.chevron_right, color: color, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  static String _labelFor(ReservationStatus s) {
    switch (s) {
      case ReservationStatus.confirmed:
        return 'Confirmar';
      case ReservationStatus.seated:
        return 'Sentar al cliente';
      case ReservationStatus.completed:
        return 'Completar';
      case ReservationStatus.noShow:
        return 'No se presentó';
      case ReservationStatus.cancelled:
        return 'Cancelar';
      case ReservationStatus.pending:
        return 'Pendiente';
    }
  }
}

class _InlineEmpty extends StatelessWidget {
  final IconData icon;
  final String message;

  const _InlineEmpty({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.textHint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
