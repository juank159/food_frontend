import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/utils/role_labels.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/employee.dart';
import '../controllers/employee_detail_controller.dart';

/// Employee Detail Page — pantalla de detalle de empleado.
///
/// Estructura:
///   - `AppGradientHeader` con avatar, nombre, rol y status pill.
///   - Sección "Estadísticas del empleado" con KPI chips.
///   - Sección "Información personal" con email/teléfono/código/fecha/salario.
///   - Acciones rápidas: suspender / activar / eliminar (con confirmación).
///   - FAB "Editar empleado" → ruta `editEmployee`.
class EmployeeDetailPage extends GetView<EmployeeDetailController> {
  const EmployeeDetailPage({super.key});

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
                _skeletonHeader(),
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }
          if (controller.hasError) {
            return Column(
              children: [
                _skeletonHeader(),
                Expanded(
                  child: AppErrorState(
                    message: controller.errorMessage.value,
                    onRetry: controller.reload,
                  ),
                ),
              ],
            );
          }
          final emp = controller.employee.value;
          if (emp == null) return const SizedBox.shrink();
          return _buildLoaded(emp);
        }),
      ),
      bottomNavigationBar: Obx(() {
        if (!controller.isLoaded) return const SizedBox.shrink();
        return AppPrimaryActionBar(
          label: 'Editar empleado',
          icon: Icons.edit_outlined,
          onPressed: () => _onEdit(controller.employee.value!),
        );
      }),
    );
  }

  // ─────────────────────────── Header ───────────────────────────

  Widget _skeletonHeader() {
    return AppGradientHeader(
      title: 'Empleado',
      subtitle: 'Cargando detalle…',
      leading: _BackButton(),
    );
  }

  Widget _buildHeader(Employee emp) {
    return AppGradientHeader(
      title: emp.fullName,
      subtitle: roleLabelEs(emp.role?.code, fallback: emp.role?.name),
      leading: _BackButton(),
      trailing: _StatusPillLight(status: emp.status),
      hero: _AvatarHero(employee: emp),
    );
  }

  // ─────────────────────────── Body ───────────────────────────

  Widget _buildLoaded(Employee emp) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: controller.reload,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(emp),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatsSection(emp),
                const SizedBox(height: 16),
                _buildPersonalSection(emp),
                const SizedBox(height: 16),
                _buildActionsSection(emp),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(Employee emp) {
    return _DetailSection(
      title: 'Estadísticas del empleado',
      icon: Icons.insights_outlined,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _MiniStat(
            icon: Icons.receipt_long_outlined,
            label: 'Órdenes manejadas',
            value: emp.totalOrdersHandled.toString(),
            tint: AppColors.primary,
          ),
          _MiniStat(
            icon: Icons.payments_outlined,
            label: 'Ventas totales',
            value: CurrencyFormatter.format(emp.totalSalesAmount),
            tint: AppColors.success,
          ),
          _MiniStat(
            icon: Icons.star_outline,
            label: 'Servicio promedio',
            value: emp.averageServiceRating != null
                ? '${emp.averageServiceRating!.toStringAsFixed(1)} / 5'
                : 'Sin datos',
            tint: AppColors.warning,
          ),
          _MiniStat(
            icon: Icons.access_time,
            label: 'Última actividad',
            value: emp.lastLogin != null
                ? _relativeDate(emp.lastLogin!)
                : 'Sin registros',
            tint: AppColors.info,
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalSection(Employee emp) {
    final rows = <Widget>[
      _InfoRow(
        icon: Icons.alternate_email,
        label: 'Email',
        value: emp.email,
      ),
      if (emp.phone != null && emp.phone!.isNotEmpty)
        _InfoRow(
          icon: Icons.phone_outlined,
          label: 'Teléfono',
          value: emp.phone!,
        ),
      if (emp.employeeCode != null && emp.employeeCode!.isNotEmpty)
        _InfoRow(
          icon: Icons.badge_outlined,
          label: 'Código de empleado',
          value: emp.employeeCode!,
        ),
      _InfoRow(
        icon: Icons.event_outlined,
        label: 'Fecha de contratación',
        value: emp.hireDate != null
            ? _formatDate(emp.hireDate!)
            : 'No registrada',
      ),
      _InfoRow(
        icon: Icons.attach_money,
        label: 'Salario',
        value: emp.salary != null
            ? CurrencyFormatter.format(emp.salary!)
            : 'No asignado',
      ),
      if (emp.notes != null && emp.notes!.isNotEmpty)
        _InfoRow(
          icon: Icons.sticky_note_2_outlined,
          label: 'Notas',
          value: emp.notes!,
          multiline: true,
        ),
    ];

    return _DetailSection(
      title: 'Información personal',
      icon: Icons.person_outline,
      accent: AppColors.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 16, color: AppColors.divider),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _buildActionsSection(Employee emp) {
    return _DetailSection(
      title: 'Acciones',
      icon: Icons.settings_outlined,
      accent: AppColors.warning,
      child: Obx(() {
        final disabled = controller.isMutating.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (emp.isActive)
              _ActionButton(
                icon: Icons.pause_circle_outline,
                label: 'Suspender empleado',
                description:
                    'Bloquea el acceso temporalmente. Se puede reactivar luego.',
                tint: AppColors.warning,
                onTap:
                    disabled ? null : controller.suspendEmployee,
              )
            else
              _ActionButton(
                icon: Icons.play_circle_outline,
                label: 'Activar empleado',
                description: 'Restaura el acceso al sistema.',
                tint: AppColors.success,
                onTap:
                    disabled ? null : controller.activateEmployee,
              ),
            const SizedBox(height: 8),
            _ActionButton(
              icon: Icons.delete_outline,
              label: 'Eliminar empleado',
              description: 'Acción permanente. Pide confirmación.',
              tint: AppColors.error,
              onTap: disabled ? null : controller.deleteEmployee,
            ),
          ],
        );
      }),
    );
  }

  // ─────────────────────────── Acciones ───────────────────────────

  Future<void> _onEdit(Employee emp) async {
    final result = await Get.toNamed(
      AppRoutes.buildEditEmployee(emp.id),
      arguments: emp,
    );
    if (result != null) controller.reload();
  }

  // ─────────────────────────── Helpers ─────────────────────────── //

  static String _relativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.isNegative) return _formatDate(date);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'ayer';
    if (diff.inDays < 7) return 'hace ${diff.inDays} d';
    if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return 'hace $weeks sem';
    }
    return _formatDate(date);
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

// ─────────────────────────── Sub-widgets ───────────────────────────

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
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

class _StatusPillLight extends StatelessWidget {
  final EmployeeStatus status;
  const _StatusPillLight({required this.status});

  Color get _dotColor {
    switch (status) {
      case EmployeeStatus.active:
        return AppColors.accent;
      case EmployeeStatus.suspended:
        return Colors.redAccent;
      case EmployeeStatus.inactive:
        return Colors.white70;
    }
  }

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
            decoration: BoxDecoration(
              color: _dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarHero extends StatelessWidget {
  final Employee employee;
  const _AvatarHero({required this.employee});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              employee.initials,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        roleLabelEs(
                          employee.role?.code,
                          fallback: employee.role?.name,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.alternate_email,
                      size: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        employee.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tint;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: tint),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: tint,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ],
            ),
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

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.multiline = false,
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
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color tint;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: enabled ? 0.08 : 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: tint.withValues(alpha: enabled ? 0.2 : 0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        color: enabled ? tint : AppColors.textHint,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: enabled ? tint : AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
