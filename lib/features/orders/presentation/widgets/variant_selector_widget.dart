import 'package:flutter/material.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/domain/entities/product_variant.dart';

/// Selector de variantes (tamaños, tipos, etc.) para un producto.
///
/// Diseño: cards con borde + radio button + nombre + precio. Cuando hay
/// una variante seleccionada el card se destaca con borde primary y un
/// fondo tintado del brand. Usa `AppColors` directos (no `theme.colorScheme`)
/// para garantizar contraste consistente independientemente del theme.
class VariantSelectorWidget extends StatefulWidget {
  final Product product;
  final ProductVariant? initialVariant;
  final ValueChanged<ProductVariant>? onChanged;

  const VariantSelectorWidget({
    super.key,
    required this.product,
    this.initialVariant,
    this.onChanged,
  });

  @override
  State<VariantSelectorWidget> createState() => VariantSelectorWidgetState();
}

class VariantSelectorWidgetState extends State<VariantSelectorWidget> {
  ProductVariant? _selectedVariant;

  @override
  void initState() {
    super.initState();
    _selectedVariant = widget.initialVariant ??
        widget.product.defaultVariant ??
        (widget.product.availableVariants.isNotEmpty
            ? widget.product.availableVariants.first
            : null);

    if (_selectedVariant != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onChanged?.call(_selectedVariant!);
      });
    }
  }

  ProductVariant? getSelectedVariant() => _selectedVariant;

  void setSelectedVariant(ProductVariant? variant) {
    if (variant != null && widget.product.availableVariants.contains(variant)) {
      setState(() {
        _selectedVariant = variant;
      });
      widget.onChanged?.call(variant);
    }
  }

  bool validate() => _selectedVariant != null;

  void _handleVariantSelection(ProductVariant variant) {
    setState(() {
      _selectedVariant = variant;
    });
    widget.onChanged?.call(variant);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.product.hasVariants) return const SizedBox.shrink();

    final availableVariants = widget.product.availableVariants;

    if (availableVariants.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: const [
              Icon(Icons.warning_amber_outlined,
                  size: 18, color: AppColors.error),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Este producto no tiene variantes disponibles.',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Decisión de layout: SIEMPRE lista vertical, independiente del
    // tamaño de pantalla.
    //
    // Por qué no grid: el selector vive dentro de modals/sheets con
    // ancho restringido (no usa el ancho de la pantalla entero), por
    // lo que `ResponsiveConfig` clasifica como desktop pero el card
    // real es muy angosto → el `childAspectRatio` del grid quedaba mal
    // y desbordaba ~129 px en vertical. Una lista resuelve esto de
    // raíz: cada card toma exactamente el alto que necesita.
    //
    // Trade-off: en desktop ancho desperdiciamos espacio horizontal,
    // pero las variantes son típicamente ≤5 — el scroll natural del
    // dialog padre absorbe sin problema y la legibilidad gana.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        _buildVariantList(availableVariants),
        if (_selectedVariant != null) ...[
          const SizedBox(height: 12),
          _buildPriceDisplay(),
        ],
      ],
    );
  }

  // ─────────────────────────── Header ───────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.tune,
            size: 16,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Seleccioná variante',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        // Badge "Requerido" — fondo tintado, texto en error sólido para
        // contraste alto siempre.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
          ),
          child: const Text(
            'Requerido',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.error,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────── List / Grid ─────────────────────────

  Widget _buildVariantList(List<ProductVariant> variants) {
    return Column(
      children: variants.map((variant) {
        final isSelected = _selectedVariant?.id == variant.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildVariantCard(variant, isSelected),
        );
      }).toList(),
    );
  }

  // ─────────────────────────── Card ───────────────────────────

  Widget _buildVariantCard(ProductVariant variant, bool isSelected) {
    final finalPrice = variant.calculateFinalPrice(widget.product.basePrice);
    final isDisabled = !variant.isAvailable;

    // Colores explícitos — NUNCA dependemos de theme.colorScheme acá porque
    // si el theme tiene `surface` ≈ blanco y `onSurface` mal definido, los
    // labels desaparecen.
    final bgColor = isSelected
        ? AppColors.primary.withValues(alpha: 0.10)
        : AppColors.cardBackground;
    final borderColor = isSelected ? AppColors.primary : AppColors.border;
    final nameColor =
        isDisabled ? AppColors.textHint : AppColors.textPrimary;
    final priceColor = isSelected ? AppColors.primary : AppColors.textPrimary;

    final showDescription = variant.description != null &&
        variant.description!.trim().isNotEmpty;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isDisabled ? null : () => _handleVariantSelection(variant),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? AppColors.primary
                    : (isDisabled
                        ? AppColors.textHint
                        : AppColors.textSecondary),
                size: 22,
              ),
              const SizedBox(width: 10),
              // Bloque central: nombre arriba, metadata (descripción +
              // badges) abajo. El nombre usa Expanded en su propia row
              // para garantizar ellipsis cuando es muy largo — el badge
              // "Por defecto" vive en la segunda fila, así no compite
              // nunca por el ancho con el nombre.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      variant.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: nameColor,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showDescription) ...[
                      const SizedBox(height: 2),
                      Text(
                        variant.description!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (variant.isDefault || isDisabled) ...[
                      const SizedBox(height: 4),
                      // Wrap permite que badge + "no disponible"
                      // se acomoden en varias filas si hace falta,
                      // sin overflow.
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (variant.isDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Por defecto',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.success,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          if (isDisabled)
                            const Text(
                              'No disponible',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Columna de precio. `mainAxisSize: min` para no estirar
              // verticalmente. El modifier solo aparece si != 0.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    CurrencyFormatter.format(finalPrice),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: priceColor,
                      letterSpacing: -0.2,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (variant.priceModifier != 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      variant.hasAdditionalCost
                          ? '+${CurrencyFormatter.format(variant.priceModifier)}'
                          : CurrencyFormatter.format(variant.priceModifier),
                      style: TextStyle(
                        fontSize: 11,
                        color: variant.hasAdditionalCost
                            ? AppColors.warning
                            : AppColors.success,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceDisplay() {
    final finalPrice =
        _selectedVariant!.calculateFinalPrice(widget.product.basePrice);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Bloque izquierdo flexible: el label se contrae con ellipsis
          // antes de empujar al precio. Antes este label era un Row sin
          // contención y empujaba el precio fuera del card en mobile
          // angosto.
          Expanded(
            child: Row(
              children: const [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.primary,
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Precio con variante',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            CurrencyFormatter.format(finalPrice),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
