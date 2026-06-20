import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/widgets/modern_card.dart';
import '../../../../core/utils/input_formatters.dart';
import '../controllers/product_form_controller.dart';
import '../../../../core/config/formatters/currency_formatter.dart';

/// Widget for editing a single product variant
class VariantFormWidget extends StatelessWidget {
  final VariantFormData variant;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onToggleDefault;

  const VariantFormWidget({
    super.key,
    required this.variant,
    required this.index,
    required this.onRemove,
    required this.onToggleDefault,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ModernCard(
      margin: EdgeInsets.only(
        bottom: 16.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with variant number and controls
          Row(
            children: [
              // Variant number badge
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 16.0,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    12.0,
                  ),
                ),
                child: Text(
                  'Variante ${index + 1}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const Spacer(),

              // Default toggle
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Por defecto',
                    style: theme.textTheme.bodySmall,
                  ),
                  SizedBox(width: 16.0),
                  Switch(
                    value: variant.isDefault,
                    onChanged: (_) => onToggleDefault(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),

              SizedBox(width: 16.0),

              // Remove button
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onRemove,
                color: theme.colorScheme.error,
                iconSize: 24.0,
                tooltip: 'Eliminar variante',
              ),
            ],
          ),

          SizedBox(height: 16.0),

          // Variant name field
          TextFormField(
            controller: variant.nameController,
            decoration: InputDecoration(
              labelText: 'Nombre de la variante *',
              hintText: 'Ej: Grande, Mediano, Picante',
              prefixIcon: const Icon(Icons.label_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  12.0,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'El nombre es requerido';
              }
              return null;
            },
          ),

          SizedBox(height: 16.0),

          // Price modifier field
          TextFormField(
            controller: variant.priceModifierController,
            decoration: InputDecoration(
              labelText: 'Modificador de precio *',
              hintText: '5.000',
              prefixIcon: const Icon(Icons.attach_money),
              helperText: 'Cantidad a sumar o restar al precio base (formato automático)',
              helperMaxLines: 2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  12.0,
                ),
              ),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              ThousandsSeparatorInputFormatter(),
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'El modificador de precio es requerido';
              }
              final parsed = NumberFormatHelper.parseFormattedInt(value);
              if (parsed == null) {
                return 'Ingresa un número válido';
              }
              return null;
            },
          ),

          SizedBox(height: 16.0),

          // SKU field (optional)
          TextFormField(
            controller: variant.skuController,
            decoration: InputDecoration(
              labelText: 'SKU (opcional)',
              hintText: 'Código único de la variante',
              prefixIcon: const Icon(Icons.qr_code),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  12.0,
                ),
              ),
            ),
            textCapitalization: TextCapitalization.characters,
          ),

          SizedBox(height: 16.0),

          // Cremas / bolas (heladería) — cuántos sabores pide esta variante.
          // Campo SOLO numérico: teclado numérico + filtro que descarta
          // cualquier carácter que no sea dígito (no deja escribir texto).
          TextFormField(
            controller: variant.scoopController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: false,
              signed: false,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2), // hasta 99 bolas, de sobra
            ],
            decoration: InputDecoration(
              labelText: 'Cantidad de cremas / bolas (opcional)',
              hintText: 'Ej: 2 → el cliente elige 2 sabores',
              helperText:
                  'Solo números. Es para heladería: cuántos sabores se eligen '
                  'con esta variante. Dejalo vacío si no lleva cremas.',
              helperMaxLines: 3,
              prefixIcon: const Icon(Icons.icecream),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
          ),

          SizedBox(height: 16.0),

          // Description field (optional)
          TextFormField(
            controller: variant.descriptionController,
            decoration: InputDecoration(
              labelText: 'Descripción (opcional)',
              hintText: 'Detalles adicionales de esta variante',
              prefixIcon: const Icon(Icons.notes),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  12.0,
                ),
              ),
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),

          SizedBox(height: 16.0),

          // Available toggle
          Row(
            children: [
              Expanded(
                child: Text(
                  'Disponible para venta',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Switch(
                value: variant.isAvailable,
                onChanged: (value) {
                  variant.isAvailable = value;
                  // Force rebuild
                  (context as Element).markNeedsBuild();
                },
              ),
            ],
          ),

          // Price preview
          if (variant.priceModifierController.text.isNotEmpty)
            _buildPricePreview(context, theme),
        ],
      ),
    );
  }

  Widget _buildPricePreview(
    BuildContext context,
    ThemeData theme,
  ) {
    final modifier = NumberFormatHelper.parseFormattedInt(variant.priceModifierController.text)?.toDouble();
    if (modifier == null) return const SizedBox.shrink();

    final isPositive = modifier > 0;
    final isNegative = modifier < 0;

    Color color;
    IconData icon;
    String text;

    if (isPositive) {
      color = theme.colorScheme.error;
      icon = Icons.arrow_upward;
      text = '+${CurrencyFormatter.format(modifier)}';
    } else if (isNegative) {
      color = Colors.green;
      icon = Icons.arrow_downward;
      text = CurrencyFormatter.format(modifier);
    } else {
      color = theme.colorScheme.onSurface.withValues(alpha: 0.6);
      icon = Icons.remove;
      text = 'Sin cambio de precio';
    }

    return Container(
      margin: EdgeInsets.only(top: 16.0),
      padding: EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 16.0,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(
          12.0,
        ),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24.0,
            color: color,
          ),
          SizedBox(width: 16.0),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
