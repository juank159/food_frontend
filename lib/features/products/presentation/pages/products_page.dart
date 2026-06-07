import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/navigation_service.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../domain/entities/product.dart';
import '../controllers/modifiers_controller.dart';
import '../controllers/products_controller.dart';
import '../widgets/product_card.dart';
import '../../../categories/presentation/controllers/categories_controller.dart';
import '../../../categories/presentation/pages/categories_page.dart';
import 'modifiers_page.dart';

/// Pantalla de gestión de productos.
///
/// Header con gradient (mismo lenguaje que Dashboard / Órdenes) que
/// integra el TabBar adentro — no hay AppBar separado, todo unificado.
/// Las 3 tabs (Productos / Categorías / Modificadores) reciben
/// `embedded: true` para que omitan su AppBar interna.
class ProductsPage extends GetView<ProductsController> {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const _ProductsHeader(),
              const Expanded(
                child: TabBarView(
                  children: [
                    _ProductsTab(),
                    CategoriesPage(embedded: true),
                    ModifiersPage(embedded: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────── Gradient header con TabBar ───────────────────────

class _ProductsHeader extends StatelessWidget {
  const _ProductsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gestión de productos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Catálogo, categorías y modificadores',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              // Menú "+" — adaptado al tab activo. Ofrecemos la creación
              // de los 3 tipos siempre, así no hace falta saber en qué tab
              // está el usuario para crear algo.
              PopupMenuButton<String>(
                icon: const Icon(Icons.add, color: Colors.white),
                tooltip: 'Crear nuevo',
                onSelected: (value) async {
                  // Esperamos el resultado y, si vino un objeto creado,
                  // hacemos insert optimista en el controller del tab
                  // correspondiente para que la lista refleje el item
                  // nuevo sin esperar el GET completo.
                  switch (value) {
                    case 'products':
                      final result =
                          await NavigationService.toCreateProduct();
                      if (result is Product) {
                        Get.find<ProductsController>()
                            .addOrReplaceProduct(result);
                      } else if (result != null) {
                        Get.find<ProductsController>().refreshProducts();
                      }
                      break;
                    case 'categories':
                      final result =
                          await NavigationService.toCreateCategory();
                      if (result != null) {
                        Get.find<CategoriesController>().refreshCategories();
                      }
                      break;
                    case 'modifiers':
                      final result =
                          await NavigationService.toCreateModifier();
                      if (result != null) {
                        Get.find<ModifiersController>().refreshModifiers();
                      }
                      break;
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'products',
                    child: Row(children: [
                      Icon(FontAwesomeIcons.bowlFood, size: 16),
                      SizedBox(width: 12),
                      Text('Nuevo producto'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'categories',
                    child: Row(children: [
                      Icon(FontAwesomeIcons.layerGroup, size: 16),
                      SizedBox(width: 12),
                      Text('Nueva categoría'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'modifiers',
                    child: Row(children: [
                      Icon(FontAwesomeIcons.circlePlus, size: 16),
                      SizedBox(width: 12),
                      Text('Nuevo modificador'),
                    ]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // TabBar con look custom — pill blanca para el tab activo, en
          // lugar del subrayado clásico de Material que se ve débil sobre
          // el gradient.
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: TabBar(
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.white,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: 'Productos'),
                Tab(text: 'Categorías'),
                Tab(text: 'Modificadores'),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

// ─────────────────────────── Tab: Productos ───────────────────────────

class _ProductsTab extends GetView<ProductsController> {
  const _ProductsTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _ProductsSearchBar(),
        Expanded(
          child: Obx(() {
            if (controller.isLoading.value && controller.products.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.errorMessage.value.isNotEmpty &&
                controller.products.isEmpty) {
              return AppErrorState(
                message: controller.errorMessage.value,
                onRetry: controller.refreshProducts,
              );
            }
            if (controller.products.isEmpty) {
              return AppEmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Aún no hay productos',
                message:
                    'Empezá creando tu primer producto. Vas a poder asignarle categoría, variantes y modificadores.',
                actionLabel: 'Crear producto',
                actionIcon: Icons.add,
                onAction: () async {
                  final result = await NavigationService.toCreateProduct();
                  if (result is Product) {
                    controller.addOrReplaceProduct(result);
                  } else if (result != null) {
                    controller.refreshProducts();
                  }
                },
              );
            }
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: controller.refreshProducts,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final cross = width > 1200
                      ? 4
                      : width > 800
                          ? 3
                          : width > 600
                              ? 2
                              : 1;
                  final cardWidth =
                      (width - 16 * 2 - 16 * (cross - 1)) / cross;
                  // El card tiene imagen 16:10 + bloque de info. Forzamos
                  // un aspect entre 0.65 (más alto que ancho, mobile) y
                  // 0.95 (cuasi-cuadrado, desktop denso) para que el
                  // contenido nunca se apriete contra la imagen.
                  final aspect = (cardWidth / 320).clamp(0.65, 0.95);
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      childAspectRatio: aspect,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: controller.products.length,
                    itemBuilder: (context, index) {
                      final product = controller.products[index];
                      return ProductCard(
                        product: product,
                        onTap: () => _openProductDetail(product),
                      );
                    },
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }

  /// Tap en una card → detalle del producto (no edición directa).
  ///
  /// Pasamos `product` como `arguments` para que el detalle muestre algo
  /// al instante (cache) y refresque vía GET en background. Si la edición
  /// modifica algo (vuelve con `result != null`), refrescamos la lista
  /// para que el cambio se vea sin esperar el reentry.
  void _openProductDetail(Product product) async {
    final result = await NavigationService.toProductDetail(
      product.id,
      product: product,
    );
    if (result != null) controller.refreshProducts();
  }
}

/// Search bar siempre visible (no escondida en un dialog). Patrón de
/// Stripe Dashboard / Linear / Shopify Admin — el filtro nunca está
/// a más de 1 click.
class _ProductsSearchBar extends GetView<ProductsController> {
  const _ProductsSearchBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  textInputAction: TextInputAction.search,
                  onSubmitted: controller.searchProducts,
                  decoration: InputDecoration(
                    hintText: 'Buscar productos…',
                    hintStyle: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.border, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.border, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Toggle "solo disponibles" — lo más común al gestionar el menú.
              Obx(() => _ToggleIconButton(
                    active: controller.showOnlyAvailable.value,
                    onTap: controller.toggleAvailableFilter,
                    activeIcon: Icons.visibility,
                    inactiveIcon: Icons.visibility_outlined,
                    tooltip: controller.showOnlyAvailable.value
                        ? 'Mostrando solo disponibles'
                        : 'Mostrar todos',
                  )),
            ],
          ),
          // Chips de filtros activos (búsqueda, categoría) — fila inline,
          // no banner separado. Cada uno se puede quitar con la X.
          Obx(() {
            final activeFilters = <Widget>[
              if (controller.searchQuery.value.isNotEmpty)
                _ActiveFilterPill(
                  icon: Icons.search,
                  label: '"${controller.searchQuery.value}"',
                  onClear: () {
                    controller.searchQuery.value = '';
                    controller.loadProducts();
                  },
                ),
              if (controller.selectedCategoryId.value != null)
                _ActiveFilterPill(
                  icon: Icons.layers,
                  label: 'Categoría',
                  onClear: () => controller.filterByCategory(null),
                ),
            ];
            if (activeFilters.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: activeFilters,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ToggleIconButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String tooltip;

  const _ToggleIconButton({
    required this.active,
    required this.onTap,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? AppColors.primary : AppColors.border,
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              active ? activeIcon : inactiveIcon,
              size: 20,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveFilterPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onClear;

  const _ActiveFilterPill({
    required this.icon,
    required this.label,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClear,
            child: Icon(
              Icons.close,
              size: 14,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
