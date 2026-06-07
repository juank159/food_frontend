import 'package:flutter/material.dart';

/// Chip elegante para mostrar estadísticas
/// Reutilizable en todo el app (mesas, ordenes, productos, etc.)
class StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? iconColor;
  final Color? backgroundColor;
  final bool isCompact;

  const StatChip({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
    this.backgroundColor,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.primaryColor;

    if (isCompact) {
      return _buildCompactChip(context, theme, effectiveIconColor);
    }

    return _buildFullChip(context, theme, effectiveIconColor);
  }

  Widget _buildCompactChip(BuildContext context, ThemeData theme, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(
            value,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullChip(BuildContext context, ThemeData theme, Color iconColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: backgroundColor ?? iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Grupo de chips de estadísticas con separadores
class StatChipGroup extends StatelessWidget {
  final List<StatChip> chips;
  final Axis direction;
  final double spacing;
  final bool showDividers;

  const StatChipGroup({
    super.key,
    required this.chips,
    this.direction = Axis.horizontal,
    this.spacing = 16,
    this.showDividers = true,
  });

  @override
  Widget build(BuildContext context) {
    if (direction == Axis.horizontal) {
      return Row(
        children: _buildChipsWithDividers(context),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _buildChipsWithDividers(context),
    );
  }

  List<Widget> _buildChipsWithDividers(BuildContext context) {
    final List<Widget> widgets = [];

    for (int i = 0; i < chips.length; i++) {
      widgets.add(chips[i]);

      if (i < chips.length - 1) {
        if (showDividers && direction == Axis.horizontal) {
          widgets.add(SizedBox(width: spacing));
          widgets.add(
            Container(
              width: 1,
              height: 24,
              color: Theme.of(context).dividerColor,
            ),
          );
          widgets.add(SizedBox(width: spacing));
        } else {
          widgets.add(SizedBox(
            width: direction == Axis.horizontal ? spacing : 0,
            height: direction == Axis.vertical ? spacing : 0,
          ));
        }
      }
    }

    return widgets;
  }
}
