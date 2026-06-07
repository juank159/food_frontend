import 'package:flutter/material.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../domain/entities/modifier.dart';
import '../../../../core/config/formatters/currency_formatter.dart';

/// Tarjeta de modificador — diseño compacto con avatar tintado por
/// tipo, precio prominente y acciones overflow.
class ModifierCard extends StatelessWidget {
  final Modifier modifier;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const ModifierCard({
    super.key,
    required this.modifier,
    this.onTap,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final type = _typeData();
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
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: type.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        type.icon,
                        color: type.color,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            modifier.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            type.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: type.color,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onEdit != null || onDelete != null)
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        padding: EdgeInsets.zero,
                        onSelected: (v) {
                          if (v == 'edit') onEdit?.call();
                          if (v == 'delete') onDelete?.call();
                        },
                        itemBuilder: (_) => [
                          if (onEdit != null)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [
                                Icon(Icons.edit_outlined, size: 16),
                                SizedBox(width: 10),
                                Text('Editar'),
                              ]),
                            ),
                          if (onDelete != null)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: AppColors.error,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Eliminar',
                                  style: TextStyle(color: AppColors.error),
                                ),
                              ]),
                            ),
                        ],
                      ),
                  ],
                ),
                if (modifier.description != null &&
                    modifier.description!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    modifier.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
                const Spacer(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _AvailabilityBadge(available: modifier.isAvailable),
                    const Spacer(),
                    _PriceBadge(price: modifier.price),
                  ],
                ),
                if (modifier.maxQuantity != null) ...[
                  const SizedBox(height: 8),
                  _MaxBadge(maxQty: modifier.maxQuantity!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  ({String label, IconData icon, Color color}) _typeData() {
    switch (modifier.type.value) {
      case 'addition':
        return (
          label: 'Agregar',
          icon: Icons.add_circle_outline,
          color: AppColors.success,
        );
      case 'removal':
        return (
          label: 'Quitar',
          icon: Icons.remove_circle_outline,
          color: AppColors.error,
        );
      case 'substitution':
        return (
          label: 'Sustituir',
          icon: Icons.swap_horiz,
          color: AppColors.info,
        );
      default:
        return (
          label: modifier.type.value,
          icon: Icons.info_outline,
          color: AppColors.textSecondary,
        );
    }
  }
}

class _AvailabilityBadge extends StatelessWidget {
  final bool available;
  const _AvailabilityBadge({required this.available});

  @override
  Widget build(BuildContext context) {
    final color = available ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
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
            available ? 'Disponible' : 'Inactivo',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceBadge extends StatelessWidget {
  final double price;
  const _PriceBadge({required this.price});

  @override
  Widget build(BuildContext context) {
    final hasCost = price > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: hasCost
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasCost
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Text(
        hasCost ? '+${CurrencyFormatter.format(price)}' : 'Gratis',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: hasCost ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _MaxBadge extends StatelessWidget {
  final int maxQty;
  const _MaxBadge({required this.maxQty});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.shopping_cart_outlined,
            size: 11,
            color: AppColors.info,
          ),
          const SizedBox(width: 4),
          Text(
            'Máx: $maxQty',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.info,
            ),
          ),
        ],
      ),
    );
  }
}
