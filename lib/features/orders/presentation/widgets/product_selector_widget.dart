import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/responsive_config.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/widgets/app_filter_chip.dart';
import '../../../../core/widgets/barcode_scanner_page.dart';
import '../../../../core/widgets/modern_card.dart';
import '../../../flavors/data/datasources/flavor_remote_datasource.dart';
import '../../../flavors/domain/entities/flavor.dart';
import '../../../categories/presentation/bindings/categories_binding.dart';
import '../../../categories/presentation/controllers/categories_controller.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/domain/entities/product_variant.dart';
import '../../../products/presentation/bindings/products_binding.dart';
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
    // Auto-binding defensivo: el selector se abre desde el form de
    // orden; si el usuario nunca entró a Productos en esta sesión, el
    // controller no está en memoria y `Get.find` truena.
    if (!Get.isRegistered<ProductsController>()) {
      ProductsBinding().dependencies();
    }
    final productsController = Get.find<ProductsController>();

    // Categorías para los chips de salto rápido entre secciones.
    if (!Get.isRegistered<CategoriesController>()) {
      CategoriesBinding().dependencies();
    }
    final categoriesController = Get.find<CategoriesController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with search
        Padding(
          padding: EdgeInsets.all(responsive.isMobile ? 8 : responsive.padding / 2),
          child: _buildHeader(context, productsController, responsive),
        ),

        // Chips de categoría — salto instantáneo entre secciones (Todos /
        // Heladería / Especiales / Comida…). Filtrado client-side.
        _buildCategoryChips(productsController, categoriesController),

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

            // Catálogo vacío de verdad (sin productos cargados).
            if (productsController.products.isEmpty) {
              return _buildEmptyState(context);
            }

            // Filtro de texto local (instantáneo, sin requests al backend).
            final visible = productsController.filteredProducts;
            if (visible.isEmpty) {
              return _buildNoMatchesState(
                context,
                productsController.searchQuery.value,
              );
            }

            return _buildProductsGrid(context, visible, responsive);
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
        // Escanear código de barras (mobile/tablet) → filtra el catálogo
        // por el código leído (busca por barcode/sku).
        if (!responsive.isDesktop) ...[
          SizedBox(width: responsive.isMobile ? 6 : responsive.spacing),
          IconButton.filledTonal(
            icon: Icon(Icons.qr_code_scanner,
                size: responsive.isMobile ? 18 : 20),
            tooltip: 'Escanear código',
            padding: responsive.isMobile ? EdgeInsets.zero : null,
            constraints: responsive.isMobile
                ? const BoxConstraints(minWidth: 40, minHeight: 40)
                : null,
            onPressed: () async {
              final code = await scanBarcode(context);
              if (code != null && code.isNotEmpty) {
                controller.searchProducts(code);
              }
            },
          ),
        ],
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

  /// Fila horizontal de chips de categoría para saltar de sección al
  /// instante. Solo lista las categorías activas que tienen productos en
  /// el catálogo (no muestra secciones vacías), ordenadas por su orden.
  /// Filtrado client-side → cambiar de sección es inmediato, sin requests.
  Widget _buildCategoryChips(
    ProductsController pc,
    CategoriesController cc,
  ) {
    return Obx(() {
      final presentIds = pc.products.map((p) => p.categoryId).toSet();
      final cats = cc.categories
          .where((c) => c.isActive && presentIds.contains(c.id))
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      // Con 0 ó 1 categoría la fila no aporta — la ocultamos.
      if (cats.length < 2) return const SizedBox.shrink();

      final selected = pc.selectedCategoryId.value;
      return SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            AppFilterChip(
              label: 'Todos',
              selected: selected == null,
              onTap: () => pc.filterByCategory(null),
            ),
            for (final c in cats)
              AppFilterChip(
                label: c.name,
                selected: selected == c.id,
                onTap: () =>
                    pc.filterByCategory(selected == c.id ? null : c.id),
              ),
          ],
        ),
      );
    });
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
          // La categoría seleccionada ya se ve resaltada en la fila de
          // chips de arriba — no repetimos un pill acá.
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
        // Más columnas en pantallas grandes para ver más productos sin
        // scroll. Mobile sigue en 1 (layout de fila compacta).
        crossAxisCount: responsive.getGridColumns(
          mobile: 1,
          tablet: 3,
          desktop: 4,
          largeDesktop: 5,
        ),
        crossAxisSpacing: responsive.isMobile ? 8 : responsive.spacing,
        mainAxisSpacing: responsive.isMobile ? 8 : responsive.spacing,
        childAspectRatio: responsive.getChildAspectRatio(
          // Mobile: fila compacta (imagen 80px + padding). 3.0 deja que el
          // nombre + descripción + precio entren sin desbordar pero sigue
          // mostrando varios productos por pantalla.
          mobile: 3.0,
          tablet: 0.82,
          desktop: 0.85,
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
        // Tap en la card = abrir el detalle (cantidad + NOTAS para cocina +
        // variantes/cremas si tiene). Así se le puede poner "sin cebolla" a
        // cualquier producto, no solo a los de heladería. El agregado rápido
        // sin abrir nada queda en el botón "+" (y su stepper).
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
                        'Agotado',
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

          // Product Info - Compact. La descripción va en Expanded para que
          // se achique/ellipsice y la card NUNCA desborde la celda del grid
          // (causaba el overflow de 25-43px en pantallas chicas).
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (product.description.isNotEmpty)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        product.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (stockBadge != null) stockBadge,
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        CurrencyFormatter.format(product.basePrice),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildAddControl(context, product, isAvailable,
                        compact: true),
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
                    _buildAddControl(context, product, isAvailable,
                        compact: false),
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

  /// Control de agregado en el card. Tres estados:
  ///   - Producto con variante/modificadores → botón que abre el detalle
  ///     (cada combinación es una línea distinta, no se puede stepper).
  ///   - Producto simple sin nada en el carrito → botón "+" (agrega 1).
  ///   - Producto simple ya en el carrito → stepper [− qty +] para sumar
  ///     o restar unidades al instante, sin abrir nada.
  /// Vive dentro del `Obx` del card (que ya depende de `cartItems`), así
  /// que la cantidad se actualiza sola.
  Widget _buildAddControl(
    BuildContext context,
    Product product,
    bool isAvailable, {
    required bool compact,
  }) {
    final theme = Theme.of(context);
    final hasOptions =
        product.hasVariants || product.modifierGroups.any((g) => g.isActive);
    final qty = orderController.plainCartQuantity(product);
    final double dim = compact ? 32 : 36;
    final double iconSize = compact ? 18 : 20;

    if (hasOptions || qty == 0) {
      return IconButton.filledTonal(
        icon: Icon(hasOptions ? Icons.tune : Icons.add, size: iconSize),
        onPressed:
            isAvailable ? () => _addToCart(context, product) : null,
        tooltip: !isAvailable
            ? 'Agotado'
            : hasOptions
                ? 'Elegir opciones'
                : 'Agregar',
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(minWidth: dim, minHeight: dim),
      );
    }

    // Stepper compacto [− qty +]. Material propio para garantizar el
    // ripple sin depender de un ancestro Material del card.
    Widget circle(IconData icon, VoidCallback? onTap) {
      return Material(
        color: onTap == null
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.primaryContainer,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: dim,
            height: dim,
            child: Icon(
              icon,
              size: iconSize,
              color: onTap == null
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        circle(Icons.remove, () => orderController.decrementPlain(product)),
        Container(
          constraints: BoxConstraints(minWidth: compact ? 22 : 28),
          alignment: Alignment.center,
          child: Text(
            '$qty',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        circle(
          Icons.add,
          isAvailable
              ? () => orderController.addToCart(product, silent: true)
              : null,
        ),
      ],
    );
  }

  Widget _buildNoMatchesState(BuildContext context, String query) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'Sin resultados para "$query"',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Probá con otro nombre.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart(BuildContext context, Product product) {
    // Siempre abrir el sheet para permitir agregar nota al cocinero,
    // incluso si el producto no tiene variantes ni modificadores.
    _showProductDetails(context, product);
  }

  void _showProductDetails(BuildContext context, Product product) {
    // Buscar la categoría para obtener quick notes y flavor label.
    List<String> quickNotes = const [];
    String? flavorLabel;
    if (Get.isRegistered<CategoriesController>()) {
      final cats = Get.find<CategoriesController>().categories;
      try {
        final cat = cats.firstWhere((c) => c.id == product.categoryId);
        quickNotes = cat.quickNotes;
        flavorLabel = cat.flavorLabel;
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _ProductDetailsSheet(
        product: product,
        categoryQuickNotes: quickNotes,
        categoryFlavorLabel: flavorLabel,
        onAddItems: (items) {
          for (final it in items) {
            orderController.addToCart(
              product,
              quantity: it.quantity,
              variant: it.variant,
              modifiers: it.modifiers,
              specialInstructions: it.note,
              flavorIds: it.flavorIds.isEmpty ? null : it.flavorIds,
              flavorNames: it.flavorNames.isEmpty ? null : it.flavorNames,
            );
          }
          Navigator.pop(sheetCtx);
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

// ─────────────── Modelo de ítem para agregar al carrito ───────────────

class _CartItemEntry {
  final int quantity;
  final ProductVariant? variant;
  final List<SelectedModifier>? modifiers;
  final String? note;
  final List<String> flavorIds;
  final List<String> flavorNames;

  const _CartItemEntry({
    required this.quantity,
    this.variant,
    this.modifiers,
    this.note,
    this.flavorIds = const [],
    this.flavorNames = const [],
  });
}

// ─────────────────── Product Details Sheet ───────────────────────────

/// Sheet rediseñado con:
/// • Footer sticky (botón siempre visible aunque el teclado esté abierto)
/// • Quick tags de nota rápida (sin cebolla, sin tomate…)
/// • Modo "Por ítem" para dar nota individual a cada unidad cuando qty > 1
class _ProductDetailsSheet extends StatefulWidget {
  final Product product;
  final void Function(List<_CartItemEntry> items) onAddItems;
  /// Quick notes y flavor label vienen de la categoría del producto.
  final List<String> categoryQuickNotes;
  final String? categoryFlavorLabel;

  const _ProductDetailsSheet({
    required this.product,
    required this.onAddItems,
    this.categoryQuickNotes = const [],
    this.categoryFlavorLabel,
  });

  @override
  State<_ProductDetailsSheet> createState() => _ProductDetailsSheetState();
}

class _ProductDetailsSheetState extends State<_ProductDetailsSheet> {
  int _quantity = 1;
  bool _splitMode = false; // notas individuales por ítem

  final _variantKey = GlobalKey<VariantSelectorWidgetState>();
  final _modifierKey = GlobalKey<ModifierSelectorWidgetState>();

  // Nota única (modo normal)
  final _singleNoteCtrl = TextEditingController();

  // Notas individuales por ítem (split mode)
  final List<TextEditingController> _itemCtrls = [TextEditingController()];

  ProductVariant? _selectedVariant;
  List<SelectedModifier> _selectedModifiers = [];

  // Cremas
  List<Flavor> _flavors = [];
  bool _flavorsLoading = false;
  List<String?> _selectedFlavors = [];

  int get _scoopCount => _selectedVariant?.scoopCount ?? 0;

  static const _defaultQuickTags = [
    'Sin cebolla', 'Sin tomate', 'Sin salsas', 'Sin sal',
    'Sin mayonesa', 'Bien hecho', 'A punto', 'Extra queso',
    'Sin ají', 'Sin pepinillo', 'Poco picante', 'Muy picante',
  ];

  List<String> get _quickTags => widget.categoryQuickNotes.isNotEmpty
      ? widget.categoryQuickNotes
      : _defaultQuickTags;

  @override
  void initState() {
    super.initState();
    _loadFlavors();
  }

  Future<void> _loadFlavors() async {
    setState(() => _flavorsLoading = true);
    try {
      final list = await sl<FlavorRemoteDataSource>()
          .getFlavors(categoryId: widget.product.categoryId);
      if (!mounted) return;
      setState(() {
        _flavors = list.where((f) => f.isAvailable).toList();
        _flavorsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _flavorsLoading = false);
    }
  }

  void _syncFlavorSlots() {
    final n = _scoopCount;
    if (_selectedFlavors.length != n) {
      _selectedFlavors = List<String?>.filled(n, null);
    }
  }

  void _setQty(int v) {
    setState(() {
      _quantity = v;
      _syncItemCtrls();
    });
  }

  void _syncItemCtrls() {
    while (_itemCtrls.length < _quantity) {
      _itemCtrls.add(TextEditingController());
    }
    while (_itemCtrls.length > _quantity) {
      _itemCtrls.last.dispose();
      _itemCtrls.removeLast();
    }
  }

  void _toggleSplit(bool v) {
    setState(() {
      _splitMode = v;
      _syncItemCtrls();
    });
  }

  void _appendTag(TextEditingController ctrl, String tag) {
    final cur = ctrl.text.trim();
    ctrl.text = cur.isEmpty ? tag : '$cur, $tag';
    setState(() {});
  }

  @override
  void dispose() {
    _singleNoteCtrl.dispose();
    for (final c in _itemCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  double _calcTotal() {
    double base = widget.product.basePrice;
    if (_selectedVariant != null) {
      base = _selectedVariant!.calculateFinalPrice(base);
    }
    final mods = _selectedModifiers.fold<double>(0, (s, m) => s + m.subtotal);
    return (base + mods) * _quantity;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.product;
    final kbBottom = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: imagen + nombre + precio
                  if (product.imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        product.imageUrl!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        CurrencyFormatter.format(product.basePrice),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (product.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      product.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (product.preparationTime > 0 ||
                      product.allergens.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (product.preparationTime > 0)
                          _InfoChip(
                            icon: Icons.timer_outlined,
                            label: '${product.preparationTime} min',
                          ),
                        for (final a in product.allergens)
                          _InfoChip(
                            icon: Icons.warning_amber_outlined,
                            label: a,
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Variante
                  if (product.hasVariants) ...[
                    VariantSelectorWidget(
                      key: _variantKey,
                      product: product,
                      onChanged: (v) => setState(() {
                        _selectedVariant = v;
                        _syncFlavorSlots();
                      }),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Cremas heladería
                  if (_scoopCount > 0) ...[
                    _buildFlavorSelector(theme),
                    const SizedBox(height: 16),
                  ],

                  // Modificadores
                  if (product.hasModifiers) ...[
                    ModifierSelectorWidget(
                      key: _modifierKey,
                      product: product,
                      onChanged: () => setState(() {
                        _selectedModifiers =
                            _modifierKey.currentState?.getSelectedModifiers() ??
                                [];
                      }),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ─────── SECCIÓN DE NOTAS ───────
                  _NotesSection(
                    splitMode: _splitMode,
                    quantity: _quantity,
                    singleCtrl: _singleNoteCtrl,
                    itemCtrls: _itemCtrls,
                    quickTags: _quickTags,
                    onToggleSplit: _quantity > 1 ? _toggleSplit : null,
                    onAppendTag: _appendTag,
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ─────── FOOTER STICKY ───────
          _AddFooter(
            quantity: _quantity,
            total: _calcTotal(),
            kbBottom: kbBottom,
            safeBottom: safeBottom,
            onDecrement: _quantity > 1 ? () => _setQty(_quantity - 1) : null,
            onIncrement: () => _setQty(_quantity + 1),
            onAdd: _handleAdd,
          ),
        ],
      ),
    );
  }

  void _handleAdd() {
    if (widget.product.hasVariants) {
      final ok = _variantKey.currentState?.validate() ?? true;
      if (!ok || _selectedVariant == null) {
        AppSnackbar.show('Variante requerida',
            'Selecciona una variante del producto');
        return;
      }
    }
    if (widget.product.hasModifiers) {
      final ok = _modifierKey.currentState?.validateAllGroups() ?? true;
      if (!ok) {
        AppSnackbar.show(
            'Selecciones requeridas', 'Completa las opciones requeridas');
        return;
      }
    }
    if (_scoopCount > 0) {
      final label = widget.categoryFlavorLabel ?? 'Cremas';
      if (_flavors.isEmpty) {
        AppSnackbar.show('Faltan $label',
            'Cargá las $label en Productos → Cremas / Sabores.');
        return;
      }
      if (_selectedFlavors.any((f) => f == null)) {
        AppSnackbar.show('Elegí las $label',
            'Selecciona ${_scoopCount > 1 ? 'las $_scoopCount' : 'la'} $label.');
        return;
      }
    }

    final modifiers = _modifierKey.currentState?.getSelectedModifiers();
    final flavorIds = <String>[];
    final flavorNames = <String>[];
    if (_scoopCount > 0) {
      for (final id in _selectedFlavors) {
        if (id == null) continue;
        flavorIds.add(id);
        flavorNames
            .add(_flavors.firstWhere((f) => f.id == id).name);
      }
    }

    if (_splitMode) {
      // N ítems individuales, qty=1 cada uno
      widget.onAddItems([
        for (int i = 0; i < _quantity; i++)
          _CartItemEntry(
            quantity: 1,
            variant: _selectedVariant,
            modifiers: modifiers,
            note: _itemCtrls[i].text.trim().isEmpty
                ? null
                : _itemCtrls[i].text.trim(),
            flavorIds: flavorIds,
            flavorNames: flavorNames,
          ),
      ]);
    } else {
      final note = _singleNoteCtrl.text.trim();
      widget.onAddItems([
        _CartItemEntry(
          quantity: _quantity,
          variant: _selectedVariant,
          modifiers: modifiers,
          note: note.isEmpty ? null : note,
          flavorIds: flavorIds,
          flavorNames: flavorNames,
        ),
      ]);
    }
  }

  Widget _buildFlavorSelector(ThemeData theme) {
    final label = widget.categoryFlavorLabel ?? 'Cremas';
    if (_flavorsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_flavors.isEmpty) {
      return Text(
        'No hay $label cargadas. Ve a Productos → Cremas / Sabores.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.icecream, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text('$label ($_scoopCount selección${_scoopCount == 1 ? '' : 'es'})',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < _scoopCount; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  child: Text('Bola ${i + 1}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedFlavors[i],
                    isExpanded: true,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      hintText: 'Elegí…',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    items: [
                      for (final f in _flavors)
                        DropdownMenuItem(value: f.id, child: Text(f.name)),
                    ],
                    onChanged: (v) => setState(() => _selectedFlavors[i] = v),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────── Helper widgets ───────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ─── Sección de notas con quick tags y modo por ítem ────────────────

class _NotesSection extends StatelessWidget {
  final bool splitMode;
  final int quantity;
  final TextEditingController singleCtrl;
  final List<TextEditingController> itemCtrls;
  final List<String> quickTags;
  final ValueChanged<bool>? onToggleSplit;
  final void Function(TextEditingController, String) onAppendTag;

  const _NotesSection({
    required this.splitMode,
    required this.quantity,
    required this.singleCtrl,
    required this.itemCtrls,
    required this.quickTags,
    required this.onToggleSplit,
    required this.onAppendTag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            Icon(Icons.sticky_note_2_outlined,
                size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              splitMode
                  ? 'Nota por ítem ($quantity)'
                  : 'Nota para el cocinero',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (onToggleSplit != null) ...[
              const Spacer(),
              GestureDetector(
                onTap: () => onToggleSplit!(!splitMode),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: splitMode
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        splitMode
                            ? Icons.view_list
                            : Icons.format_list_numbered,
                        size: 13,
                        color: splitMode
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        splitMode ? 'Nota única' : 'Por ítem',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: splitMode
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),

        if (!splitMode) ...[
          // Quick tags
          _QuickTagsRow(
            tags: quickTags,
            onTap: (tag) => onAppendTag(singleCtrl, tag),
          ),
          const SizedBox(height: 8),
          // Single note field
          TextField(
            controller: singleCtrl,
            maxLines: 2,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Ej. sin cebolla, bien hecho, sin sal…',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              counterText: '',
            ),
          ),
        ] else ...[
          // N cards, una por ítem
          for (int i = 0; i < quantity; i++)
            _ItemNoteCard(
              index: i,
              ctrl: itemCtrls[i],
              quickTags: quickTags,
              onAppendTag: onAppendTag,
            ),
        ],
      ],
    );
  }
}

class _QuickTagsRow extends StatelessWidget {
  final List<String> tags;
  final ValueChanged<String> onTap;
  const _QuickTagsRow({required this.tags, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          return GestureDetector(
            onTap: () => onTap(tags[i]),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer
                    .withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                tags[i],
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ItemNoteCard extends StatelessWidget {
  final int index;
  final TextEditingController ctrl;
  final List<String> quickTags;
  final void Function(TextEditingController, String) onAppendTag;

  const _ItemNoteCard({
    required this.index,
    required this.ctrl,
    required this.quickTags,
    required this.onAppendTag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ítem ${index + 1}',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          _QuickTagsRow(
            tags: quickTags,
            onTap: (tag) => onAppendTag(ctrl, tag),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            maxLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Nota (opcional)…',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Footer sticky con cantidad + botón ─────────────────────────────

class _AddFooter extends StatelessWidget {
  final int quantity;
  final double total;
  final double kbBottom;
  final double safeBottom;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onAdd;

  const _AddFooter({
    required this.quantity,
    required this.total,
    required this.kbBottom,
    required this.safeBottom,
    required this.onDecrement,
    required this.onIncrement,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPad = kbBottom > 0 ? kbBottom + 8 : safeBottom + 12;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPad),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          // Qty stepper compacto
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QtyBtn(
                  icon: Icons.remove,
                  onTap: onDecrement,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    '$quantity',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _QtyBtn(icon: Icons.add, onTap: onIncrement),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Botón principal
          Expanded(
            child: FilledButton(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: EdgeInsets.zero,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Agregar al carrito',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    CurrencyFormatter.format(total),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(
          icon,
          size: 18,
          color: onTap == null
              ? Theme.of(context).colorScheme.outlineVariant
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

// ─────── Flavor selector helper (kept from old code, now separate) ──

