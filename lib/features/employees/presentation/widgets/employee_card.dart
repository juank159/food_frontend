import 'package:flutter/material.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/role_labels.dart';
import '../../domain/entities/employee.dart';

/// Acciones disponibles desde el menú contextual de la card.
enum EmployeeCardAction { edit, suspend, activate, delete }

/// Tarjeta de empleado — mismo lenguaje visual que `OrderCard`:
///
///   - Stripe vertical de color por estado (verde activo, rojo suspendido,
///     gris inactivo).
///   - Avatar con iniciales tintado del color del estado.
///   - Header con el nombre + rol como chip.
///   - Línea inferior con email/teléfono y botón de menú con acciones.
class EmployeeCard extends StatelessWidget {
  final Employee employee;
  final VoidCallback? onTap;
  final ValueChanged<EmployeeCardAction>? onAction;

  const EmployeeCard({
    super.key,
    required this.employee,
    this.onTap,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(employee.status);
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Stripe lateral con el color del estado.
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(statusColor),
                        const SizedBox(height: 10),
                        _buildContactRow(),
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

  // ─────────────────────────── Header ────────────────────────────

  Widget _buildHeader(Color statusColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar con iniciales tintado del color del estado.
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.25),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            employee.initials,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: statusColor,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                employee.fullName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _RoleChip(
                    roleName: roleLabelEs(
                      employee.role?.code,
                      fallback: employee.role?.name,
                    ),
                  ),
                  _StatusPill(
                    status: employee.status,
                    color: statusColor,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        _buildMenuButton(),
      ],
    );
  }

  // ─────────────────────────── Contact ───────────────────────────

  Widget _buildContactRow() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _InfoChip(
          icon: Icons.alternate_email,
          label: employee.email,
        ),
        if (employee.phone != null && employee.phone!.isNotEmpty)
          _InfoChip(
            icon: Icons.phone_outlined,
            label: employee.phone!,
          ),
        if (employee.employeeCode != null &&
            employee.employeeCode!.isNotEmpty)
          _InfoChip(
            icon: Icons.badge_outlined,
            label: employee.employeeCode!,
          ),
      ],
    );
  }

  // ─────────────────────────── Menu ──────────────────────────────

  Widget _buildMenuButton() {
    return PopupMenuButton<EmployeeCardAction>(
      tooltip: 'Acciones',
      icon: const Icon(
        Icons.more_vert,
        size: 20,
        color: AppColors.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onSelected: (value) => onAction?.call(value),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: EmployeeCardAction.edit,
          child: _MenuRow(icon: Icons.edit_outlined, label: 'Editar'),
        ),
        if (employee.isActive)
          const PopupMenuItem(
            value: EmployeeCardAction.suspend,
            child: _MenuRow(
              icon: Icons.pause_circle_outline,
              label: 'Suspender',
              tint: AppColors.warning,
            ),
          )
        else
          const PopupMenuItem(
            value: EmployeeCardAction.activate,
            child: _MenuRow(
              icon: Icons.play_circle_outline,
              label: 'Activar',
              tint: AppColors.success,
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: EmployeeCardAction.delete,
          child: _MenuRow(
            icon: Icons.delete_outline,
            label: 'Eliminar',
            tint: AppColors.error,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────── Helpers ───────────────────────────

  static Color _statusColor(EmployeeStatus status) {
    switch (status) {
      case EmployeeStatus.active:
        return AppColors.success;
      case EmployeeStatus.suspended:
        return AppColors.error;
      case EmployeeStatus.inactive:
        return AppColors.textSecondary;
    }
  }
}

class _StatusPill extends StatelessWidget {
  final EmployeeStatus status;
  final Color color;

  const _StatusPill({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
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

class _RoleChip extends StatelessWidget {
  final String roleName;

  const _RoleChip({required this.roleName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.workspace_premium_outlined,
            size: 12,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            roleName,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

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
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? tint;

  const _MenuRow({
    required this.icon,
    required this.label,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final color = tint ?? AppColors.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
