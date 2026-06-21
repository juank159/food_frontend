import 'package:flutter/material.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../domain/entities/product.dart';

/// Tarjeta de producto — diseño moderno consistente con `OrderCard` y
/// `_FloorPlanCard`. Imagen arriba, info abajo con jerarquía clara.
class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildImage(),
              // Expanded permite que el bloque de info ocupe el alto sobrante
              // del card sin importar cómo el grid resuelva el aspect ratio,
              // y absorbe la diferencia cuando el contenido sería más alto
              // que el espacio disponible.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Bloque superior: nombre + descripción. Flexible
                      // alrededor de la descripción la deja achicarse
                      // (ellipsis) cuando el card está apretado.
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          if (product.description.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              product.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Bloque inferior: precio + tiempo (+ badges si aplica).
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  CurrencyFormatter.format(product.basePrice),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              if (product.preparationTime > 0)
                                _MiniBadge(
                                  icon: Icons.timer_outlined,
                                  label: '${product.preparationTime} min',
                                ),
                            ],
                          ),
                          if (_hasStatusBadges()) ...[
                            const SizedBox(height: 6),
                            // Limita la altura de los badges a una sola línea
                            // para no romper el card. `Wrap` con clip evita
                            // el overflow si hay muchos.
                            ClipRect(
                              child: SizedBox(
                                height: 20,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  children: [
                                    for (final badge in _buildStatusBadges()) ...[
                                      badge,
                                      const SizedBox(width: 4),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  // ─────────────────────────── Image ───────────────────────────

  Widget _buildImage() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: AspectRatio(
        aspectRatio: 1,
        child: product.imageUrl != null && product.imageUrl!.isNotEmpty
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: AppColors.background),
                  Image.network(
                    product.imageUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                  ),
                  if (!product.isAvailable)
                    Container(
                      color: Colors.black.withValues(alpha: 0.4),
                      alignment: Alignment.center,
                      child: const Text(
                        'NO DISPONIBLE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                ],
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.background, AppColors.divider],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.restaurant_menu,
          size: 38,
          color: AppColors.textHint,
        ),
      ),
    );
  }

  // ─────────────────────────── Status badges ───────────────────────────

  bool _hasStatusBadges() =>
      !product.isAvailable ||
      product.isOutOfStock ||
      product.isLowStock ||
      product.tags.isNotEmpty;

  List<Widget> _buildStatusBadges() {
    final badges = <Widget>[];
    if (!product.isAvailable) {
      badges.add(const _StatusBadge(
        label: 'No disponible',
        color: AppColors.error,
      ));
    }
    if (product.isOutOfStock) {
      badges.add(const _StatusBadge(
        label: 'Agotado',
        color: AppColors.warning,
      ));
    } else if (product.isLowStock) {
      badges.add(const _StatusBadge(
        label: 'Stock bajo',
        color: AppColors.warning,
      ));
    }
    badges.addAll(
      product.tags.take(2).map(
            (tag) => _StatusBadge(label: tag, color: AppColors.info),
          ),
    );
    return badges;
  }
}

class _MiniBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
