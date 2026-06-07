import 'package:flutter/material.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../domain/entities/category.dart';

/// Tarjeta de categoría — diseño moderno con stripe vertical de color
/// (igual lenguaje visual que `OrderCard`).
class CategoryCard extends StatelessWidget {
  final Category category;
  final VoidCallback? onTap;
  final bool showChildren;

  const CategoryCard({
    super.key,
    required this.category,
    this.onTap,
    this.showChildren = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _resolveColor();
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildIcon(accent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    category.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                      height: 1.1,
                                    ),
                                  ),
                                  if (category.description.trim().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      category.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusPill(active: category.isActive),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _MiniInfo(
                              icon: category.isRootCategory
                                  ? Icons.folder_outlined
                                  : Icons.subdirectory_arrow_right,
                              label: category.isRootCategory
                                  ? 'Raíz'
                                  : 'Subcategoría',
                            ),
                            if (showChildren && category.hasChildren)
                              _MiniInfo(
                                icon: Icons.account_tree_outlined,
                                label:
                                    '${category.children.length} ${category.children.length == 1 ? "hija" : "hijas"}',
                              ),
                            _MiniInfo(
                              icon: Icons.sort,
                              label: 'Orden ${category.displayOrder}',
                            ),
                          ],
                        ),
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

  Widget _buildIcon(Color accent) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: category.imageUrl != null && category.imageUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                category.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.category, color: accent, size: 20),
              ),
            )
          : Icon(Icons.category, color: accent, size: 20),
    );
  }

  /// Si la categoría tiene un color hex configurado, lo usamos. Si no,
  /// usamos el primary del brand.
  ///
  /// Acepta los formatos: `#RGB`, `RGB`, `#RRGGBB`, `RRGGBB`,
  /// `#AARRGGBB`, `AARRGGBB`. Si el string viene basura caemos al brand
  /// sin tirar excepción.
  Color _resolveColor() {
    final hex = category.color;
    if (hex == null) return AppColors.primary;
    final trimmed = hex.trim();
    if (trimmed.isEmpty) return AppColors.primary;
    try {
      var clean = trimmed.replaceAll('#', '').replaceAll(' ', '');
      if (clean.length == 3) {
        // #RGB → #RRGGBB (cada hex se duplica)
        clean = clean.split('').map((c) => '$c$c').join();
      }
      if (clean.length == 6) clean = 'FF$clean';
      if (clean.length != 8) return AppColors.primary;
      // Validar que sólo tenga hex chars antes de parsear.
      if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean)) {
        return AppColors.primary;
      }
      return Color(int.parse(clean, radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }
}

class _StatusPill extends StatelessWidget {
  final bool active;
  const _StatusPill({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.textSecondary;
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
            active ? 'Activa' : 'Inactiva',
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
          // El chip vive dentro de un `Wrap`: si el label es muy largo
          // queremos que se acorte con ellipsis en lugar de empujar el
          // ancho del chip más allá del card.
          Flexible(
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
