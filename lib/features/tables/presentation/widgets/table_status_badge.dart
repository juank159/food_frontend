import 'package:flutter/material.dart';
import '../../../../core/config/constants/table_enums.dart';
import '../../../../core/config/theme/app_colors.dart';

/// Table Status Badge Widget
/// Badge reutilizable para mostrar el estado de una mesa
class TableStatusBadge extends StatelessWidget {
  final TableStatus status;
  final bool showIcon;
  final double fontSize;

  const TableStatusBadge({
    super.key,
    required this.status,
    this.showIcon = true,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(status);
    final icon = _getStatusIcon(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showIcon ? 8 : 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              icon,
              size: fontSize + 4,
              color: color,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            status.displayName,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(TableStatus status) {
    switch (status) {
      case TableStatus.available:
        return AppColors.success;
      case TableStatus.occupied:
        return AppColors.error;
      case TableStatus.reserved:
        return AppColors.info;
      case TableStatus.cleaning:
        return AppColors.warning;
      case TableStatus.maintenance:
        return AppColors.categoryPurple;
      case TableStatus.unavailable:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(TableStatus status) {
    switch (status) {
      case TableStatus.available:
        return Icons.check_circle;
      case TableStatus.occupied:
        return Icons.people;
      case TableStatus.reserved:
        return Icons.bookmark;
      case TableStatus.cleaning:
        return Icons.cleaning_services;
      case TableStatus.maintenance:
        return Icons.construction;
      case TableStatus.unavailable:
        return Icons.block;
    }
  }
}
