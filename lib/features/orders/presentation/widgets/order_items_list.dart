import 'package:flutter/material.dart';
import '../../../../core/config/constants/modifier_enums.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/modern_card.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_item.dart';
import '../../domain/entities/order_item_modifier.dart';
import '../../../../core/config/formatters/currency_formatter.dart';

/// Order Items List
/// Lista de items de la orden con totales
class OrderItemsList extends StatelessWidget {
  final Order order;

  const OrderItemsList({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ModernCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.restaurant_menu,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Items de la Orden',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${order.totalItems} items',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // Items
            ...order.items.map((item) => _buildOrderItem(theme, item)),

            const Divider(height: 24),

            // Totals
            _buildTotalRow(theme, 'Subtotal', order.subtotal),
            if (order.effectiveDiscount > 0) ...[
              const SizedBox(height: 8),
              _buildTotalRow(
                theme,
                'Descuento',
                -order.effectiveDiscount,
                color: Colors.green,
              ),
            ],
            if (order.taxAmount > 0) ...[
              const SizedBox(height: 8),
              _buildTotalRow(theme, 'Impuestos', order.taxAmount),
            ],
            if (order.deliveryFee > 0) ...[
              const SizedBox(height: 8),
              _buildTotalRow(theme, 'Envío', order.deliveryFee),
            ],
            if (order.tipAmount > 0) ...[
              const SizedBox(height: 8),
              _buildTotalRow(theme, 'Propina', order.tipAmount),
            ],

            const Divider(height: 16),

            _buildTotalRow(
              theme,
              'Total',
              order.totalAmount,
              isHighlight: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(ThemeData theme, OrderItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quantity Badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${item.quantity}x',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Item Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Modifiers ("sin cebolla", "extra queso", etc.). Sin
                // este bloque, las personalizaciones que el operario
                // marca al crear la orden no se ven en el detalle, y
                // la cocina/cliente no se entera. Cada modifier va con
                // su propio icono según el tipo (removal/addition/
                // substitution) para que se distinga de un vistazo.
                if (item.hasModifiers) ...[
                  const SizedBox(height: 6),
                  ...item.modifiers
                      .map((m) => _buildModifierLine(theme, m)),
                ],
                if (item.specialInstructions != null &&
                    item.specialInstructions!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.sticky_note_2_outlined,
                        size: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.specialInstructions!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${CurrencyFormatter.format(item.unitPrice)} c/u',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Subtotal
          Text(
            '${CurrencyFormatter.format(item.subtotal)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  /// Render de una línea de modifier dentro del item.
  ///
  /// Convención visual:
  /// - `removal` ("sin cebolla") → icono `remove_circle_outline` rojo
  /// - `addition` ("extra queso") → icono `add_circle_outline` verde,
  ///   con precio si tiene costo
  /// - `substitution` → icono `swap_horiz` ámbar
  Widget _buildModifierLine(ThemeData theme, OrderItemModifier mod) {
    IconData icon;
    Color color;
    switch (mod.type) {
      case ModifierType.removal:
        icon = Icons.remove_circle_outline;
        color = AppColors.error;
        break;
      case ModifierType.addition:
        icon = Icons.add_circle_outline;
        color = AppColors.success;
        break;
      case ModifierType.substitution:
        icon = Icons.swap_horiz;
        color = AppColors.warning;
        break;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              mod.displayText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (mod.hasCost)
            Text(
              mod.priceText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    ThemeData theme,
    String label,
    double amount, {
    Color? color,
    bool isHighlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isHighlight
              ? theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                )
              : theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
        ),
        Text(
          '${CurrencyFormatter.format(amount.abs())}',
          style: isHighlight
              ? theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                )
              : theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
        ),
      ],
    );
  }
}
