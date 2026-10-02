import 'package:flutter/material.dart';
import '../../domain/entities/table_status.dart';
import '../../../../core/config/constants/table_enums.dart';
import '../../../../core/config/formatters/datetime_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../domain/enums/table_capacity.dart';
import '../../../../core/widgets/widgets.dart';

class TableStatusCard extends StatelessWidget {
  final TableStatusEntity tableStatus;
  final VoidCallback onTap;

  const TableStatusCard({
    super.key,
    required this.tableStatus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusConfig = _getStatusConfig(tableStatus.status);
    final isOccupied = tableStatus.status == TableStatus.occupied;

    return HoverCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      elevation: 1,
      hoverElevation: 4,
      child: Row(
        children: [
          // Ícono con estado
          IconContainer(
            icon: statusConfig.icon,
            iconColor: statusConfig.color,
            backgroundColor: statusConfig.color.withValues(alpha: 0.12),
            size: 52,
            style: IconContainerStyle.soft,
          ),

          const SizedBox(width: 16),

          // Información de la mesa
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre y capacidad
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tableStatus.tableLabel ??
                            'Mesa ${tableStatus.tableElementId.substring(0, 8)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (tableStatus.tableCapacity != null) ...[
                      const SizedBox(width: 8),
                      StatChip(
                        icon: Icons.person,
                        value: '${tableStatus.tableCapacity!.toCapacityNumber() ?? tableStatus.tableCapacity}',
                        label: '',
                        iconColor: theme.primaryColor.withValues(alpha: 0.7),
                        isCompact: true,
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 8),

                // Estado y detalles
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBadge(
                      label: statusConfig.label,
                      color: statusConfig.color,
                      icon: statusConfig.icon,
                      isCompact: true,
                      showPulse: isOccupied,
                    ),
                    if (tableStatus.partySize != null)
                      _buildInfoChip(
                        context,
                        Icons.people,
                        '${tableStatus.partySize} personas',
                      ),
                    if (tableStatus.occupiedDuration != null)
                      _buildInfoChip(
                        context,
                        Icons.access_time,
                        _formatDuration(tableStatus.occupiedDuration!),
                      ),
                    // Hora de la reserva, bien visible — antes solo se
                    // veía (si acaso) escondida en la nota en itálica de
                    // más abajo. Útil sobre todo ahora que una reserva
                    // real del módulo de Reservaciones marca la mesa
                    // sola (ver ReservationsService._syncTableStatus en
                    // el backend) — el anfitrión necesita ver de un
                    // vistazo "reservada para las 7:00 PM", no abrir la
                    // mesa para enterarse.
                    if (tableStatus.status == TableStatus.reserved &&
                        tableStatus.reservedAt != null)
                      _buildInfoChip(
                        context,
                        Icons.schedule,
                        DateTimeFormatter.time12(tableStatus.reservedAt!),
                      ),
                  ],
                ),

                // Notas si existen
                if (tableStatus.notes != null && tableStatus.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.note,
                        size: 14,
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          tableStatus.notes!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Flecha
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right,
            color: theme.dividerColor,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // Mismos colores semánticos que usa el resto de la pantalla (la hoja
  // de acciones que se abre al tocar la mesa, los chips del header) —
  // antes esta tarjeta usaba `Colors.green[700]`/`Colors.red[700]`
  // crudos, que no coincidían exactamente con `AppColors.success`/
  // `AppColors.error` del resto de la app: una mesa "ocupada" se veía
  // de un rojo distinto en la lista que en la hoja de acciones.
  _StatusConfig _getStatusConfig(TableStatus status) {
    switch (status) {
      case TableStatus.available:
        return _StatusConfig(
          icon: Icons.check_circle,
          color: AppColors.success,
          label: 'Disponible',
        );
      case TableStatus.occupied:
        return _StatusConfig(
          icon: Icons.people,
          color: AppColors.error,
          label: 'Ocupada',
        );
      case TableStatus.reserved:
        return _StatusConfig(
          icon: Icons.event,
          color: AppColors.warning,
          label: 'Reservada',
        );
      case TableStatus.cleaning:
        return _StatusConfig(
          icon: Icons.cleaning_services,
          color: AppColors.info,
          label: 'Limpieza',
        );
      case TableStatus.maintenance:
        return _StatusConfig(
          icon: Icons.build,
          color: AppColors.textSecondary,
          label: 'Mantenimiento',
        );
      case TableStatus.unavailable:
        return _StatusConfig(
          icon: Icons.block,
          color: AppColors.textPrimary,
          label: 'No disponible',
        );
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class _StatusConfig {
  final IconData icon;
  final Color color;
  final String label;

  _StatusConfig({
    required this.icon,
    required this.color,
    required this.label,
  });
}
