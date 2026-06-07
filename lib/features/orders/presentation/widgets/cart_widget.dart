import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/modern_card.dart';
import '../../../../core/config/responsive_config.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/formatters/input_formatters.dart';
import '../controllers/order_form_controller.dart';

/// Cart Widget
/// Widget moderno para mostrar el carrito de compras con cálculos en tiempo real
class CartWidget extends StatelessWidget {
  final OrderFormController controller;
  final bool isCompact;

  const CartWidget({
    super.key,
    required this.controller,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 16),
        Expanded(
          child: Obx(() {
            if (controller.cartItems.isEmpty) {
              return _buildEmptyCart(context);
            }

            return _buildCartContent(context);
          }),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final responsive = ResponsiveConfig(context);
    // En mobile bajamos el tamaño del título y el botón "Limpiar" para que
    // no se acumule presión sobre el ancho del row (~320-360px).
    final titleStyle = responsive.isMobile
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.isMobile ? 8 : 0,
      ),
      child: Row(
        children: [
          Icon(
            Icons.shopping_cart,
            color: theme.colorScheme.primary,
            size: responsive.isMobile ? 20 : 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Carrito',
              style: titleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Obx(() {
            if (controller.cartItems.isEmpty) return const SizedBox.shrink();
            return TextButton.icon(
              icon: Icon(
                Icons.delete_outline,
                size: responsive.isMobile ? 16 : 18,
              ),
              label: Text(
                'Limpiar',
                style: TextStyle(fontSize: responsive.isMobile ? 12 : 14),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.isMobile ? 8 : 12,
                  vertical: responsive.isMobile ? 4 : 8,
                ),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => _showClearCartDialog(context),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Carrito vacío',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega productos para comenzar',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartContent(BuildContext context) {
    final responsive = ResponsiveConfig(context);

    // En móviles, todo debe hacer scroll junto
    if (responsive.isMobile) {
      return SingleChildScrollView(
        child: Column(
          children: [
            // Cart Items
            Obx(() => ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.only(bottom: responsive.spacing),
                  itemCount: controller.cartItems.length,
                  separatorBuilder: (context, index) => SizedBox(height: responsive.spacing),
                  itemBuilder: (context, index) {
                    final item = controller.cartItems[index];
                    return _buildCartItem(context, item, index);
                  },
                )),
            // Summary Section
            _buildSummary(context),
          ],
        ),
      );
    }

    // En desktop/tablet, mantener el diseño original
    return Column(
      children: [
        // Cart Items List
        Expanded(
          child: Obx(() => ListView.separated(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: controller.cartItems.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = controller.cartItems[index];
                  return _buildCartItem(context, item, index);
                },
              )),
        ),

        // Summary Section
        _buildSummary(context),
      ],
    );
  }

  Widget _buildCartItem(
    BuildContext context,
    CartItem item,
    int index,
  ) {
    final theme = Theme.of(context);
    final responsive = ResponsiveConfig(context);

    return ModernCard(
      child: Padding(
        padding: EdgeInsets.all(responsive.isMobile ? 8 : 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Container(
              width: responsive.isMobile ? 50 : 60,
              height: responsive.isMobile ? 50 : 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: item.product.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(item.product.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: item.product.imageUrl == null
                    ? theme.colorScheme.surfaceContainerHighest
                    : null,
              ),
              child: item.product.imageUrl == null
                  ? Icon(
                      Icons.restaurant,
                      size: responsive.isMobile ? 20 : 24,
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  : null,
            ),
            SizedBox(width: responsive.isMobile ? 8 : 12),

            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: (responsive.isMobile
                        ? theme.textTheme.bodyMedium
                        : theme.textTheme.titleSmall)?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: responsive.isMobile ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: responsive.isMobile ? 2 : 4),
                  Text(
                    '${CurrencyFormatter.format(item.unitPrice)} c/u',
                    style: (responsive.isMobile
                        ? theme.textTheme.bodySmall?.copyWith(fontSize: 11)
                        : theme.textTheme.bodySmall)?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                  // Variant (if selected)
                  if (item.selectedVariant != null) ...[
                    SizedBox(height: responsive.isMobile ? 2 : 4),
                    Row(
                      children: [
                        Icon(
                          Icons.tune,
                          size: responsive.isMobile ? 12 : 14,
                          color: theme.colorScheme.primary,
                        ),
                        SizedBox(width: 4),
                        // El nombre de variante puede ser largo ("Doble queso
                        // con extra panceta XL"). Flexible + ellipsis evita
                        // que empuje al pricetag de la derecha y rompa el row.
                        Flexible(
                          child: Text(
                            'Variante: ${item.selectedVariant!.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: (responsive.isMobile
                                ? theme.textTheme.bodySmall
                                : theme.textTheme.bodyMedium)?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (item.selectedVariant!.priceModifier != 0) ...[
                          SizedBox(width: 4),
                          Text(
                            item.selectedVariant!.hasAdditionalCost
                                ? '(+${CurrencyFormatter.format(item.selectedVariant!.priceModifier)})'
                                : '(${CurrencyFormatter.format(item.selectedVariant!.priceModifier)})',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: item.selectedVariant!.hasAdditionalCost
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.tertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],

                  // Modifiers (if any)
                  if (item.hasModifiers) ...[
                    SizedBox(height: responsive.isMobile ? 4 : 6),
                    _buildModifiersList(context, item, responsive),
                  ],

                  // Special instructions del item (texto libre tipo "sin
                  // cebolla", "bien cocido"). Si ya hay texto, lo mostramos
                  // como chip con icono — tap para editar. Si no hay texto,
                  // botón inline "+ Agregar nota".
                  SizedBox(height: responsive.isMobile ? 4 : 6),
                  _buildItemNoteRow(context, item, index),

                  SizedBox(height: responsive.isMobile ? 4 : 8),

                  // Quantity Controls
                  Row(
                    children: [
                      _buildQuantityButton(
                        context,
                        Icons.remove,
                        () => controller.updateQuantity(index, item.quantity - 1),
                      ),
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: responsive.isMobile ? 4 : 8),
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.isMobile ? 8 : 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.quantity.toString(),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      _buildQuantityButton(
                        context,
                        Icons.add,
                        () => controller.updateQuantity(index, item.quantity + 1),
                      ),
                      const SizedBox(width: 8),
                      // El subtotal puede ser largo ($1.234.567,89). Usamos
                      // Expanded + ellipsis para que nunca empuje a los
                      // botones de cantidad y rompa el row.
                      Expanded(
                        child: Text(
                          CurrencyFormatter.format(item.subtotal),
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (responsive.isMobile
                              ? theme.textTheme.titleSmall
                              : theme.textTheme.titleMedium)?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Delete Button
            IconButton(
              icon: Icon(Icons.close, size: responsive.isMobile ? 18 : 20),
              onPressed: () => _showDeleteItemDialog(context, index, item),
              tooltip: 'Eliminar',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: responsive.isMobile ? 32 : 40,
                minHeight: responsive.isMobile ? 32 : 40,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModifiersList(
    BuildContext context,
    CartItem item,
    ResponsiveConfig responsive,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(responsive.isMobile ? 6 : 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune,
                size: responsive.isMobile ? 12 : 14,
                color: theme.colorScheme.primary,
              ),
              SizedBox(width: responsive.isMobile ? 2 : 4),
              Text(
                'Modificadores:',
                style: (responsive.isMobile
                    ? theme.textTheme.bodySmall?.copyWith(fontSize: 10)
                    : theme.textTheme.bodySmall)?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.isMobile ? 2 : 4),
          ...item.selectedModifiers.map((modifier) {
            final quantityText = modifier.quantity > 1 ? '${modifier.quantity}x ' : '';
            final priceText = modifier.hasCost
                ? ' (+${CurrencyFormatter.format(modifier.subtotal)})'
                : ' (Gratis)';

            return Padding(
              padding: EdgeInsets.only(
                left: responsive.isMobile ? 12 : 16,
                top: responsive.isMobile ? 1 : 2,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: responsive.isMobile ? 10 : 12,
                    color: modifier.hasCost
                        ? theme.colorScheme.primary
                        : theme.colorScheme.secondary,
                  ),
                  SizedBox(width: responsive.isMobile ? 2 : 4),
                  Expanded(
                    child: Text(
                      '$quantityText${modifier.name}$priceText',
                      style: (responsive.isMobile
                          ? theme.textTheme.bodySmall?.copyWith(fontSize: 10)
                          : theme.textTheme.bodySmall)?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuantityButton(
    BuildContext context,
    IconData icon,
    VoidCallback onPressed,
  ) {
    final responsive = ResponsiveConfig(context);
    final size = responsive.isMobile ? 28.0 : 32.0;
    final iconSize = responsive.isMobile ? 14.0 : 16.0;

    return SizedBox(
      width: size,
      height: size,
      child: IconButton.outlined(
        icon: Icon(icon, size: iconSize),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final theme = Theme.of(context);
    final responsive = ResponsiveConfig(context);

    return ModernCard(
      gradient: LinearGradient(
        colors: [
          theme.colorScheme.primaryContainer,
          theme.colorScheme.secondaryContainer,
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(responsive.isMobile ? 12 : 16),
        child: Column(
          children: [
            // Items Count
            Obx(() => _buildSummaryRow(
                  context,
                  'Items',
                  '${controller.totalItems}',
                  isHighlight: false,
                )),
            SizedBox(height: responsive.isMobile ? 6 : 8),

            // Subtotal
            Obx(() => _buildSummaryRow(
                  context,
                  'Subtotal',
                  CurrencyFormatter.format(controller.subtotal),
                  isHighlight: false,
                )),

            // Discount
            Obx(() {
              if (controller.effectiveDiscount > 0) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildSummaryRow(
                    context,
                    'Descuento',
                    '-${CurrencyFormatter.format(controller.effectiveDiscount)}',
                    isHighlight: false,
                    color: Colors.green,
                  ),
                );
              }
              return const SizedBox.shrink();
            }),

            // Tax — solo se muestra si el tenant cobra IVA. El nombre y el
            // sufijo "(incluido)" reflejan la configuración real del tenant.
            Obx(() {
              if (!controller.taxEnabled.value || controller.taxRate.value <= 0) {
                return const SizedBox.shrink();
              }
              final pct = (controller.taxRate.value * 100);
              final pctTxt =
                  pct % 1 == 0 ? pct.toStringAsFixed(0) : pct.toStringAsFixed(2);
              final included = controller.taxIncludedInPrice.value;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _buildSummaryRow(
                  context,
                  '${controller.taxName.value} ($pctTxt%)${included ? " · incluido" : ""}',
                  CurrencyFormatter.format(controller.taxAmount),
                  isHighlight: false,
                ),
              );
            }),

            // Delivery Fee
            Obx(() {
              if (controller.deliveryFee.value > 0) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildSummaryRow(
                    context,
                    'Envío',
                    CurrencyFormatter.format(controller.deliveryFee.value),
                    isHighlight: false,
                  ),
                );
              }
              return const SizedBox.shrink();
            }),

            // Tip
            Obx(() {
              if (controller.tipAmount.value > 0) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildSummaryRow(
                    context,
                    'Propina',
                    CurrencyFormatter.format(controller.tipAmount.value),
                    isHighlight: false,
                  ),
                );
              }
              return const SizedBox.shrink();
            }),

            const Divider(height: 24),

            // Total
            Obx(() => _buildSummaryRow(
                  context,
                  'Total',
                  CurrencyFormatter.format(controller.total),
                  isHighlight: true,
                )),

            const SizedBox(height: 16),

            // Discount Actions
            _buildDiscountSection(context),

            const SizedBox(height: 12),

            // Notas de la orden — texto libre a nivel orden completa.
            // Útil para "Mesa silenciosa", "Alérgico a frutos secos",
            // "Entregar en mesa de la ventana", etc. Las instrucciones a
            // nivel ITEM se editan desde cada cart item.
            _buildOrderNoteRow(context),

            const SizedBox(height: 16),

            // Submit Button
            Obx(() => FilledButton.icon(
                  onPressed: controller.canSubmit
                      ? () => controller.submitOrder()
                      : null,
                  icon: controller.isLoading.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    controller.isLoading.value
                        ? 'Procesando...'
                        : 'Crear Orden',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    String label,
    String value, {
    bool isHighlight = false,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final responsive = ResponsiveConfig(context);

    final textStyle = isHighlight
        ? (responsive.isMobile
            ? theme.textTheme.titleMedium
            : theme.textTheme.titleLarge)?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimaryContainer,
          )
        : (responsive.isMobile
            ? theme.textTheme.bodyMedium
            : theme.textTheme.bodyLarge)?.copyWith(
            color: color ?? theme.colorScheme.onPrimaryContainer,
          );

    // Usamos `Expanded` en el label para que en pantallas chicas (320-360px)
    // el texto largo (ej: "IVA (10.5%) · incluido") haga ellipsis en lugar
    // de empujar y romper el row del summary.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: textStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildDiscountSection(BuildContext context) {
    final responsive = ResponsiveConfig(context);
    final iconSize = responsive.isMobile ? 16.0 : 18.0;

    // El botón de propina solo se muestra si la política del tenant la
    // habilita para el tipo de orden actual. Cuando no aplica, el botón de
    // descuento queda solo ocupando todo el ancho.
    return Obx(() {
      final showTip = controller.isTipApplicable;
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: Icon(Icons.discount, size: iconSize),
              label: Text(
                'Descuento',
                style: responsive.isMobile
                    ? const TextStyle(fontSize: 12)
                    : null,
              ),
              onPressed: () => _showDiscountDialog(context),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    Theme.of(context).colorScheme.onPrimaryContainer,
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.isMobile ? 8 : 12,
                  vertical: responsive.isMobile ? 8 : 12,
                ),
              ),
            ),
          ),
          if (showTip) ...[
            SizedBox(width: responsive.isMobile ? 6 : 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: Icon(Icons.attach_money, size: iconSize),
                label: Text(
                  'Propina',
                  style: responsive.isMobile
                      ? const TextStyle(fontSize: 12)
                      : null,
                ),
                onPressed: () => _showTipDialog(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      Theme.of(context).colorScheme.onPrimaryContainer,
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.isMobile ? 8 : 12,
                    vertical: responsive.isMobile ? 8 : 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    });
  }

  void _showDeleteItemDialog(
    BuildContext context,
    int index,
    CartItem item,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar ${item.product.name} del carrito?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              controller.removeFromCart(index);
              Navigator.pop(context);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showClearCartDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar carrito'),
        content: const Text('¿Eliminar todos los productos del carrito?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              controller.clearCart();
              Navigator.pop(context);
            },
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }

  void _showDiscountDialog(BuildContext context) {
    final amountController = TextEditingController();
    final percentageController = TextEditingController();
    bool isAmount = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Aplicar descuento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Monto'),
                    icon: Icon(Icons.attach_money),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Porcentaje'),
                    icon: Icon(Icons.percent),
                  ),
                ],
                selected: {isAmount},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() => isAmount = newSelection.first);
                },
              ),
              const SizedBox(height: 16),
              if (isAmount)
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Monto',
                    prefixText: '\$',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    AppInputFormatters.priceFormatter(),
                  ],
                )
              else
                TextField(
                  controller: percentageController,
                  decoration: const InputDecoration(
                    labelText: 'Porcentaje',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    AppInputFormatters.priceFormatter(),
                  ],
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.applyDiscountAmount(0);
                controller.applyDiscountPercentage(0);
                Navigator.pop(context);
              },
              child: const Text('Limpiar'),
            ),
            FilledButton(
              onPressed: () {
                if (isAmount) {
                  final amount = double.tryParse(amountController.text) ?? 0;
                  controller.applyDiscountAmount(amount);
                } else {
                  final percentage = double.tryParse(percentageController.text) ?? 0;
                  controller.applyDiscountPercentage(percentage);
                }
                Navigator.pop(context);
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTipDialog(BuildContext context) {
    final controller = this.controller;
    final tipController = TextEditingController();
    final isMandatory = controller.tipMode.value == 'mandatory';
    final allowCustom = controller.tipAllowCustomAmount.value;
    final maxAmount = controller.tipMaxAmount;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Propina'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Botones rápidos según porcentajes configurados por el tenant.
            // Si la lista está vacía (raro, pero defensivo), mostramos los
            // 3 clásicos como fallback.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final pct in (controller.tipSuggestedPercentages.isEmpty
                    ? <double>[0.10, 0.15, 0.20]
                    : controller.tipSuggestedPercentages))
                  _buildQuickTipButton(
                    context,
                    pct % 1 == 0
                        ? '${(pct * 100).toStringAsFixed(0)}%'
                        : '${CurrencyFormatter.format((pct * 100))}%',
                    pct,
                  ),
              ],
            ),
            if (allowCustom) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              TextField(
                controller: tipController,
                decoration: InputDecoration(
                  labelText: 'Monto personalizado',
                  prefixText: '\$',
                  helperText: maxAmount != null
                      ? 'Máximo permitido: \$${maxAmount.toStringAsFixed(0)}'
                      : null,
                  border: const OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  AppInputFormatters.priceFormatter(),
                ],
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                'Solo se permiten los porcentajes sugeridos por el establecimiento.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
        actions: [
          // En modo mandatory no permitimos quitar la propina. El backend
          // aplicaría el default igual, pero la UI es honesta sobre la regla.
          if (!isMandatory)
            TextButton(
              onPressed: () {
                controller.setTipAmount(0);
                Navigator.pop(context);
              },
              child: const Text('Sin propina'),
            ),
          if (allowCustom)
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(tipController.text) ?? 0;
                controller.setTipAmount(amount);
                Navigator.pop(context);
              },
              child: const Text('Aplicar'),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickTipButton(
    BuildContext context,
    String label,
    double percentage,
  ) {
    return FilledButton.tonal(
      onPressed: () {
        // Misma fórmula que el backend: porcentaje sobre la base configurada
        // (subtotal / subtotal con IVA / subtotal con descuento).
        final tip = controller.tipBaseAmount * percentage;
        controller.setTipAmount(tip);
        Navigator.pop(context);
      },
      child: Text(label),
    );
  }

  // ─────────────────────── Notas (item + orden) ───────────────────────

  /// Fila de notas del item del carrito. Si el operario ya escribió algo
  /// (`item.specialInstructions`), se muestra como chip editable con
  /// icono de nota. Si no hay nota, botón compacto "+ Nota" para abrir
  /// el dialog. Esto cubre casos típicos como "sin cebolla", "sin sal",
  /// "bien cocido" cuando NO hay un modifier estructurado disponible.
  Widget _buildItemNoteRow(BuildContext context, CartItem item, int index) {
    final note = item.specialInstructions?.trim() ?? '';
    final hasNote = note.isNotEmpty;

    return InkWell(
      onTap: () => _showItemNoteDialog(context, item, index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: hasNote
              ? Colors.amber.shade50
              : Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasNote
                ? Colors.amber.shade300
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasNote
                  ? Icons.sticky_note_2
                  : Icons.sticky_note_2_outlined,
              size: 14,
              color: hasNote
                  ? Colors.amber.shade800
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                hasNote ? note : 'Agregar nota (ej: sin cebolla)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: hasNote ? FontWeight.w600 : FontWeight.w500,
                  fontStyle: hasNote ? FontStyle.normal : FontStyle.italic,
                  color: hasNote
                      ? Colors.amber.shade900
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Icon(
              hasNote ? Icons.edit_outlined : Icons.add,
              size: 12,
              color: hasNote
                  ? Colors.amber.shade800
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// Fila de notas a nivel ORDEN — para indicaciones globales que no son
  /// de un item específico ("Mesa silenciosa", "Alérgico a frutos secos").
  /// Mismo patrón visual que `_buildItemNoteRow` pero enfocado a la orden.
  Widget _buildOrderNoteRow(BuildContext context) {
    return Obx(() {
      final note = controller.specialInstructions.value?.trim() ?? '';
      final hasNote = note.isNotEmpty;
      return InkWell(
        onTap: () => _showOrderNoteDialog(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hasNote
                ? Colors.amber.shade50
                : Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasNote
                  ? Colors.amber.shade300
                  : Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasNote ? Icons.note_alt : Icons.note_alt_outlined,
                size: 18,
                color: hasNote
                    ? Colors.amber.shade800
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasNote ? 'Nota de la orden' : 'Agregar nota a la orden',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: hasNote
                            ? Colors.amber.shade900
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (hasNote) ...[
                      const SizedBox(height: 2),
                      Text(
                        note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                          height: 1.3,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 2),
                      Text(
                        'Ej: Alérgico a frutos secos, mesa silenciosa…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                hasNote ? Icons.edit_outlined : Icons.add,
                size: 16,
                color: hasNote
                    ? Colors.amber.shade800
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      );
    });
  }

  /// Dialog para editar la nota especial de un item del carrito.
  /// Persiste con `controller.updateItemSpecialInstructions(index)`.
  void _showItemNoteDialog(BuildContext context, CartItem item, int index) {
    final controllerText = TextEditingController(
      text: item.specialInstructions ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.sticky_note_2_outlined),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Nota: ${item.product.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: controllerText,
          autofocus: true,
          maxLines: 3,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Ej: sin cebolla, bien cocido, sin sal',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.updateItemSpecialInstructions(index, null);
              Navigator.pop(ctx);
            },
            child: const Text('Quitar nota'),
          ),
          FilledButton(
            onPressed: () {
              controller.updateItemSpecialInstructions(
                index,
                controllerText.text,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  /// Dialog para editar la nota a nivel orden completa.
  void _showOrderNoteDialog(BuildContext context) {
    final controllerText = TextEditingController(
      text: controller.specialInstructions.value ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.note_alt_outlined),
            SizedBox(width: 8),
            Text('Nota de la orden'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Indicaciones generales que aplican a TODA la orden, no a un producto específico.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controllerText,
              autofocus: true,
              maxLines: 4,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:
                    'Ej: alérgico a frutos secos, mesa de la ventana, sin sal en general',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.setSpecialInstructions(null);
              Navigator.pop(ctx);
            },
            child: const Text('Quitar nota'),
          ),
          FilledButton(
            onPressed: () {
              controller.setSpecialInstructions(controllerText.text);
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
