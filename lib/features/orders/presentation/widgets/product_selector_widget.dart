import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/responsive_config.dart';
import '../../../../core/widgets/modern_card.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/domain/entities/product_variant.dart';
import '../../../products/presentation/controllers/products_controller.dart';
import '../../domain/entities/selected_modifier.dart';
import '../controllers/order_form_controller.dart';
import 'modifier_selector_widget.dart';
import 'variant_selector_widget.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Product Selector Widget
/// Widget para seleccionar productos y agregarlos al carrito
class ProductSelectorWidget extends StatelessWidget {
  final OrderFormController orderController;

  const ProductSelectorWidget({
    super.key,
    required this.orderController,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveConfig(context);
    final productsController = Get.find<ProductsController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with search
        Padding(
          padding: EdgeInsets.all(responsive.isMobile ? 8 : responsive.padding / 2),
          child: _buildHeader(context, productsController, responsive),
        ),

        // Filters
        Padding(
          padding: EdgeInsets.symmetric(horizontal: responsive.isMobile ? 8 : responsive.padding / 2),
          child: _buildFilters(context, productsController, responsive),
        ),
        SizedBox(height: responsive.isMobile ? 4 : responsive.spacing),

        // Products Grid
        Expanded(
          child: Obx(() {
            if (productsController.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }

            if (productsController.errorMessage.value.isNotEmpty) {
              return _buildErrorState(
                context,
                productsController.errorMessage.value,
                () => productsController.loadProducts(),
              );
            }

            if (productsController.products.isEmpty) {
              return _buildEmptyState(context);
            }

            return _buildProductsGrid(
              context,
              productsController.products,
              responsive,
            );
          }),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ProductsController controller,
    ResponsiveConfig responsive,
  ) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar productos...',
              hintStyle: TextStyle(fontSize: responsive.isMobile ? 13 : 14),
              prefixIcon: Icon(Icons.search, size: responsive.isMobile ? 20 : 24),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(responsive.isMobile ? 8 : 12),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              contentPadding: EdgeInsets.symmetric(
                horizontal: responsive.isMobile ? 8 : responsive.padding / 2,
                vertical: responsive.isMobile ? 8 : 16,
              ),
            ),
            style: TextStyle(fontSize: responsive.isMobile ? 13 : 14),
            onChanged: (value) => controller.searchProducts(value),
          ),
        ),
        SizedBox(width: responsive.isMobile ? 6 : responsive.spacing),
        IconButton.filledTonal(
          icon: Icon(Icons.filter_list, size: responsive.isMobile ? 18 : 20),
          onPressed: () => _showFilterDialog(context, controller),
          tooltip: 'Filtros',
          padding: responsive.isMobile ? EdgeInsets.zero : null,
          constraints: responsive.isMobile
              ? const BoxConstraints(minWidth: 40, minHeight: 40)
              : null,
        ),
      ],
    );
  }

  Widget _buildFilters(
    BuildContext context,
    ProductsController controller,
    ResponsiveConfig responsive,
  ) {
    return Obx(() {
      final hasFilters = controller.selectedCategoryId.value != null ||
          controller.showOnlyAvailable.value;

      if (!hasFilters) return const SizedBox.shrink();

      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (controller.selectedCategoryId.value != null)
            FilterChip(
              label: const Text('Categoría seleccionada'),
              onSelected: (_) => controller.filterByCategory(null),
              onDeleted: () => controller.filterByCategory(null),
              avatar: const Icon(Icons.category, size: 18),
            ),
          if (controller.showOnlyAvailable.value)
            FilterChip(
              label: const Text('Solo disponibles'),
              onSelected: (_) => controller.toggleAvailableFilter(),
              onDeleted: () => controller.toggleAvailableFilter(),
              avatar: const Icon(Icons.check_circle, size: 18),
            ),
          TextButton.icon(
            icon: const Icon(Icons.clear_all),
            label: const Text('Limpiar filtros'),
            onPressed: () => controller.clearFilters(),
          ),
        ],
      );
    });
  }

  Widget _buildProductsGrid(
    BuildContext context,
    List<Product> products,
    ResponsiveConfig responsive,
  ) {
    return GridView.builder(
      padding: EdgeInsets.all(responsive.isMobile ? 8 : responsive.spacing),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: responsive.getGridColumns(
          mobile: 1,
          tablet: 2,
          desktop: 3,
          largeDesktop: 4,
        ),
        crossAxisSpacing: responsive.isMobile ? 8 : responsive.spacing,
        mainAxisSpacing: responsive.isMobile ? 8 : responsive.spacing,
        childAspectRatio: responsive.getChildAspectRatio(
          mobile: 1.8,  // Más ancho = menos altura en móvil
          tablet: 0.75,
          desktop: 0.8,
        ),
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(context, product, responsive);
      },
    );
  }

  Widget _buildProductCard(BuildContext context, Product product, ResponsiveConfig responsive) {
    final theme = Theme.of(context);

    // Reactivo al carrito: si el operario agregó unidades del mismo producto
    // y se agota el stock, queremos que el card refleje "Agotado" sin esperar
    // un re-fetch del catálogo.
    return Obx(() {
      // Forzamos dependencia con el carrito leyendo la lista observable.
      // ignore: unused_local_variable
      final _ = orderController.cartItems.length;

      final outOfStock = orderController.isProductOutOfStock(product);
      final remaining = orderController.remainingStock(product);
      final cartFull = remaining != null && remaining <= 0;
      final isAvailable =
          product.isAvailable && !outOfStock && !cartFull;

      return HoverCard(
        onTap: isAvailable ? () => _showProductDetails(context, product) : null,
        elevation: 2,
        hoverElevation: 6,
        child: Container(
          decoration: !isAvailable
              ? BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey.shade300,
                      Colors.grey.shade400,
                    ],
                  ),
                  borderRadius:
                      BorderRadius.circular(responsive.isMobile ? 12 : 16),
                )
              : null,
          child: responsive.isMobile
              ? _buildMobileProductCard(
                  context, product, theme, isAvailable, responsive, remaining)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: _buildProductCardContent(context, product,
                              theme, isAvailable, responsive, remaining),
                        ),
                      ),
                    );
                  },
                ),
        ),
      );
    });
  }

  Widget _buildMobileProductCard(
    BuildContext context,
    Product product,
    ThemeData theme,
    bool isAvailable,
    ResponsiveConfig responsive,
    int? remaining,
  ) {
    // Mostramos un texto chico sobre el card cuando trackeamos inventario:
    // - "Agotado" cuando ya no se puede sumar más al carrito.
    // - "Quedan X" como aviso cuando queda poco frente a lo ya cargado.
    final stockBadge = _buildStockBadge(remaining);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image - Compact
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: product.imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(product.imageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: product.imageUrl == null
                  ? theme.colorScheme.surfaceContainerHighest
                  : null,
            ),
            child: Stack(
              children: [
                if (product.imageUrl == null)
                  Center(
                    child: Icon(
                      Icons.restaurant,
                      size: 32,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (!isAvailable)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'N/D',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Product Info - Compact
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  product.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (stockBadge != null) ...[
                  const SizedBox(height: 4),
                  stockBadge,
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      CurrencyFormatter.format(product.basePrice),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      onPressed: isAvailable
                          ? () => _addToCart(context, product)
                          : null,
                      tooltip: isAvailable ? 'Agregar' : 'Agotado',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildProductCardContent(
    BuildContext context,
    Product product,
    ThemeData theme,
    bool isAvailable,
    ResponsiveConfig responsive,
    int? remaining,
  ) {
    final stockBadge = _buildStockBadge(remaining);
    final isOutOfStock = remaining != null && remaining <= 0;
    return [
          // Product Image
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: product.imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(product.imageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: product.imageUrl == null
                        ? theme.colorScheme.surfaceContainerHighest
                        : null,
                  ),
                  child: product.imageUrl == null
                      ? Center(
                          child: Icon(
                            Icons.restaurant,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      : null,
                ),
                // Overlay "Agotado" cuando no se puede agregar más por stock.
                // Se monta sobre la imagen para que sea evidente a primera vista.
                if (isOutOfStock)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Agotado',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                // Status badges
                Positioned(
                  top: 8,
                  right: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!isAvailable && !isOutOfStock)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'No disponible',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (product.isLowStock && isAvailable)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Poco stock',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: responsive.spacing),

          // Product Info
          Padding(
            padding: EdgeInsets.symmetric(horizontal: responsive.spacing / 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  product.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (stockBadge != null) ...[
                  const SizedBox(height: 6),
                  stockBadge,
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      CurrencyFormatter.format(product.basePrice),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add_shopping_cart, size: 20),
                      onPressed: isAvailable
                          ? () => _addToCart(context, product)
                          : null,
                      tooltip: isAvailable ? 'Agregar al carrito' : 'Agotado',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ];
  }

  /// Construye el badge de stock que se renderea sobre el card. Devuelve
  /// `null` si el producto no trackea inventario o si tiene stock holgado.
  /// - "Agotado" cuando ya no se puede sumar más al carrito.
  /// - "Quedan X" cuando aún hay stock pero por debajo de un umbral chico
  ///   (<= 5) — ayuda al operario a no insistir si el inventario es pobre.
  Widget? _buildStockBadge(int? remaining) {
    if (remaining == null) return null;
    final isOut = remaining <= 0;
    final isLow = remaining > 0 && remaining <= 5;
    if (!isOut && !isLow) return null;
    final color = isOut ? Colors.red : Colors.orange;
    final label = isOut ? 'Agotado' : 'Quedan $remaining';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay productos disponibles',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Intenta ajustar los filtros de búsqueda',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    String message,
    VoidCallback onRetry,
  ) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error al cargar productos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addToCart(BuildContext context, Product product) {
    // Si el producto tiene variantes o grupos de modificadores activos, NO se
    // puede agregar directamente al carrito sin pasar por el selector. Si el
    // grupo es `is_required`, agregar sin elegir rompe la regla del menú y el
    // backend (cuando persista los modifiers) o el cocinero recibirían un
    // pedido incompleto. Forzamos abrir el bottom sheet de detalles que sí
    // monta `ModifierSelectorWidget` y `VariantSelectorWidget`.
    final hasActiveModifierGroups =
        product.modifierGroups.any((g) => g.isActive);
    if (product.hasVariants || hasActiveModifierGroups) {
      _showProductDetails(context, product);
      return;
    }
    orderController.addToCart(product);
  }

  void _showProductDetails(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ProductDetailsSheet(
        product: product,
        onAddToCart: (quantity, variant, modifiers) {
          orderController.addToCart(
            product,
            quantity: quantity,
            variant: variant,
            modifiers: modifiers,
          );
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showFilterDialog(
    BuildContext context,
    ProductsController controller,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtros'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() => SwitchListTile(
                  title: const Text('Solo disponibles'),
                  value: controller.showOnlyAvailable.value,
                  onChanged: (_) => controller.toggleAvailableFilter(),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.clearFilters();
              Navigator.pop(context);
            },
            child: const Text('Limpiar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }
}

/// Product Details Sheet
/// Bottom sheet con detalles del producto y selector de cantidad
class _ProductDetailsSheet extends StatefulWidget {
  final Product product;
  final Function(int quantity, ProductVariant? variant, List<SelectedModifier>? modifiers) onAddToCart;

  const _ProductDetailsSheet({
    required this.product,
    required this.onAddToCart,
  });

  @override
  State<_ProductDetailsSheet> createState() => _ProductDetailsSheetState();
}

class _ProductDetailsSheetState extends State<_ProductDetailsSheet> {
  int quantity = 1;
  final GlobalKey<VariantSelectorWidgetState> _variantKey = GlobalKey();
  final GlobalKey<ModifierSelectorWidgetState> _modifierKey = GlobalKey();
  ProductVariant? _selectedVariant;
  List<SelectedModifier> _selectedModifiers = [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.product;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Product Image
                    if (product.imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          product.imageUrl!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Product Name
                    Text(
                      product.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Price
                    Text(
                      CurrencyFormatter.format(product.basePrice),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    Text(
                      product.description,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),

                    // Additional Info
                    if (product.preparationTime > 0) ...[
                      _buildInfoRow(
                        context,
                        Icons.timer,
                        'Tiempo de preparación',
                        '${product.preparationTime} min',
                      ),
                      const SizedBox(height: 8),
                    ],

                    if (product.allergens.isNotEmpty) ...[
                      _buildInfoRow(
                        context,
                        Icons.warning_amber,
                        'Alérgenos',
                        product.allergens.join(', '),
                      ),
                      const SizedBox(height: 8),
                    ],

                    if (product.trackInventory && product.currentStock != null) ...[
                      _buildInfoRow(
                        context,
                        Icons.inventory,
                        'Stock disponible',
                        '${product.currentStock} unidades',
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Variant Selector (si el producto tiene variantes)
                    if (product.hasVariants) ...[
                      VariantSelectorWidget(
                        key: _variantKey,
                        product: product,
                        onChanged: (variant) {
                          setState(() {
                            _selectedVariant = variant;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Modifier Selector (si el producto tiene modificadores)
                    if (product.hasModifiers) ...[
                      ModifierSelectorWidget(
                        key: _modifierKey,
                        product: product,
                        onChanged: () {
                          setState(() {
                            _selectedModifiers = _modifierKey.currentState
                                    ?.getSelectedModifiers() ??
                                [];
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Quantity Selector
                    _buildQuantitySelector(theme),

                    const SizedBox(height: 24),

                    // Add to Cart Button
                    FilledButton.icon(
                      onPressed: _handleAddToCart,
                      icon: const Icon(Icons.add_shopping_cart),
                      label: Text(
                        'Agregar al carrito (${CurrencyFormatter.format(_calculateTotalPrice())})',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  double _calculateTotalPrice() {
    final product = widget.product;

    // Calcular precio base (considerando variante si existe)
    double basePrice = product.basePrice;
    if (_selectedVariant != null) {
      basePrice = _selectedVariant!.calculateFinalPrice(product.basePrice);
    }

    // Calcular precio de modificadores
    double modifiersPrice = _selectedModifiers.fold<double>(
      0.0,
      (sum, modifier) => sum + modifier.subtotal,
    );

    return (basePrice + modifiersPrice) * quantity;
  }

  void _handleAddToCart() {
    // Validate variants if product has variants
    if (widget.product.hasVariants) {
      final isValid = _variantKey.currentState?.validate() ?? true;
      if (!isValid || _selectedVariant == null) {
        AppSnackbar.show(
          'Variante requerida',
          'Por favor selecciona una variante del producto',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
          duration: const Duration(seconds: 3),
        );
        return;
      }
    }

    // Validate modifiers if product has modifier groups
    if (widget.product.hasModifiers) {
      final isValid = _modifierKey.currentState?.validateAllGroups() ?? true;
      if (!isValid) {
        AppSnackbar.show(
          'Validación requerida',
          'Por favor completa las selecciones requeridas',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
          duration: const Duration(seconds: 3),
        );
        return;
      }
    }

    // Get selected modifiers
    final modifiers = _modifierKey.currentState?.getSelectedModifiers();

    // Call the callback con variante
    widget.onAddToCart(quantity, _selectedVariant, modifiers);
  }

  Widget _buildQuantitySelector(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.outlined(
          icon: const Icon(Icons.remove),
          onPressed: quantity > 1
              ? () => setState(() => quantity--)
              : null,
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            quantity.toString(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        IconButton.outlined(
          icon: const Icon(Icons.add),
          onPressed: () => setState(() => quantity++),
        ),
      ],
    );
  }
}
