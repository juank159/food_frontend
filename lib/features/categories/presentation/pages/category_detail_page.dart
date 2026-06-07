import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/navigation_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../products/domain/entities/product.dart';
import '../../domain/entities/category.dart';
import '../controllers/category_detail_controller.dart';
import '../widgets/category_card.dart';
import '../../../products/presentation/widgets/product_card.dart';

/// Category Detail Page.
///
/// Vista de detalle de una categoría específica: muestra nombre, descripción,
/// estado, KPIs (productos totales / disponibles / agotados / subcategorías),
/// la lista de productos que pertenecen a la categoría y, si tiene children,
/// también las subcategorías. El FAB lleva a editar.
class CategoryDetailPage extends GetView<CategoryDetailController> {
  const CategoryDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Obx(() {
          if (controller.isLoading.value && controller.category.value == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.category.value == null) {
            return AppErrorState(
              message: controller.errorMessage.value.isNotEmpty
                  ? controller.errorMessage.value
                  : 'No pudimos cargar la categoría.',
              onRetry: controller.refresh,
            );
          }
          return _buildContent(context);
        }),
      ),
      bottomNavigationBar: Obx(() {
        if (controller.category.value == null) {
          return const SizedBox.shrink();
        }
        return AppPrimaryActionBar(
          label: 'Editar categoría',
          icon: Icons.edit,
          onPressed: _onEditCategory,
        );
      }),
    );
  }

  Future<void> _onEditCategory() async {
    final cat = controller.category.value;
    if (cat == null) return;
    final result = await NavigationService.toEditCategory(
      cat.id,
      category: cat,
    );
    if (result != null) {
      controller.refresh();
    }
  }

  // ─────────────────────────── Body ────────────────────────────

  Widget _buildContent(BuildContext context) {
    final category = controller.category.value!;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          _buildHeader(category),
          const SizedBox(height: 16),
          _buildProductsSection(context),
          if (controller.hasChildren) ...[
            const SizedBox(height: 16),
            _buildSubcategoriesSection(),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─────────────────────────── Header ──────────────────────────

  Widget _buildHeader(Category category) {
    return AppGradientHeader(
      title: category.name,
      subtitle: category.description.trim().isNotEmpty
          ? category.description
          : 'Detalle de la categoría',
      leading: GestureDetector(
        onTap: () => Get.back(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
      trailing: _CategoryHeaderIcon(icon: _resolveIconData(category.icon)),
      hero: _StatusHero(category: category),
      chips: [
        AppKpiChip(
          icon: Icons.restaurant_menu,
          label: 'Productos',
          value: controller.totalProducts.toString(),
        ),
        AppKpiChip(
          icon: Icons.check_circle_outline,
          label: 'Disponibles',
          value: controller.availableProducts.toString(),
        ),
        AppKpiChip(
          icon: Icons.remove_shopping_cart_outlined,
          label: 'Agotados',
          value: controller.outOfStockProducts.toString(),
        ),
        if (controller.hasChildren)
          AppKpiChip(
            icon: Icons.account_tree_outlined,
            label: 'Subcat.',
            value: controller.subcategoriesCount.toString(),
          ),
      ],
    );
  }

  // ──────────────────────── Products section ───────────────────

  Widget _buildProductsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            icon: Icons.restaurant_menu,
            title: 'Productos en esta categoría',
            subtitle: controller.isLoadingProducts.value
                ? 'Cargando…'
                : '${controller.totalProducts} producto(s)',
          ),
          const SizedBox(height: 12),
          Obx(() {
            if (controller.isLoadingProducts.value &&
                controller.products.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (controller.products.isEmpty) {
              return AppEmptyState(
                icon: Icons.restaurant_outlined,
                title: 'Sin productos',
                message:
                    'Esta categoría todavía no tiene productos asociados.',
              );
            }
            return _ProductsGrid(
              products: controller.products.toList(),
              onTap: _onTapProduct,
            );
          }),
        ],
      ),
    );
  }

  Future<void> _onTapProduct(Product product) async {
    // Misma convención que el listado de productos: mandamos el objeto
    // en `arguments` para hidratar el form sin un GET extra. Si el form
    // devuelve algo distinto a null, refrescamos el detalle por si la
    // edición cambió la membresía a la categoría.
    final result = await Get.toNamed('/products/edit', arguments: product);
    if (result != null) {
      controller.refresh();
    }
  }

  // ─────────────────────── Subcategorías section ───────────────

  Widget _buildSubcategoriesSection() {
    final children = controller.category.value?.children ?? const [];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            icon: Icons.account_tree_outlined,
            title: 'Subcategorías',
            subtitle: '${children.length} en total',
          ),
          const SizedBox(height: 12),
          for (final child in children)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CategoryCard(
                category: child,
                onTap: () => _onTapSubcategory(child),
              ),
            ),
        ],
      ),
    );
  }

  void _onTapSubcategory(Category child) {
    NavigationService.toCategoryDetail(child.id);
  }

  // ─────────────────────── Icon helpers ────────────────────────

  /// El campo `icon` de la categoría es un string libre (lo escribe el
  /// usuario en el form). Mapeamos las opciones más comunes a icons de
  /// Material; si no matchea, caemos al `category` por defecto.
  IconData _resolveIconData(String? raw) {
    if (raw == null) return Icons.category;
    final key = raw.trim().toLowerCase();
    if (key.isEmpty) return Icons.category;
    const map = <String, IconData>{
      'food': Icons.restaurant,
      'restaurant': Icons.restaurant,
      'pizza': Icons.local_pizza,
      'drink': Icons.local_drink,
      'beverage': Icons.local_bar,
      'coffee': Icons.local_cafe,
      'dessert': Icons.cake,
      'cake': Icons.cake,
      'snack': Icons.fastfood,
      'fastfood': Icons.fastfood,
      'fast_food': Icons.fastfood,
      'breakfast': Icons.free_breakfast,
      'lunch': Icons.lunch_dining,
      'dinner': Icons.dinner_dining,
      'salad': Icons.eco,
      'icecream': Icons.icecream,
      'ice_cream': Icons.icecream,
      'bakery': Icons.bakery_dining,
      'bread': Icons.bakery_dining,
      'kebab': Icons.kebab_dining,
      'soup': Icons.soup_kitchen,
      'wine': Icons.wine_bar,
      'beer': Icons.sports_bar,
      'menu': Icons.menu_book,
      'category': Icons.category,
    };
    return map[key] ?? Icons.category;
  }
}

// ───────────────────────────────────────────────────────────────────
// Internal widgets
// ───────────────────────────────────────────────────────────────────

class _CategoryHeaderIcon extends StatelessWidget {
  final IconData icon;
  const _CategoryHeaderIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

/// "Hero" debajo del título — pill con el estado activo/inactivo y
/// metadatos breves (orden de display, jerarquía).
class _StatusHero extends StatelessWidget {
  final Category category;
  const _StatusHero({required this.category});

  @override
  Widget build(BuildContext context) {
    final active = category.isActive;
    final color = active ? AppColors.success : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.success.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  active ? 'Activa' : 'Inactiva',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              category.isRootCategory
                  ? 'Categoría raíz · Orden ${category.displayOrder}'
                  : 'Subcategoría · Orden ${category.displayOrder}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
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
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductsGrid extends StatelessWidget {
  final List<Product> products;
  final ValueChanged<Product> onTap;

  const _ProductsGrid({required this.products, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Decidimos cantidad de columnas según el ancho disponible. Mismo
        // breakpoint informal que la grid de productos: 2 col en móvil,
        // 3 en tablet, 4 en desktop.
        final width = constraints.maxWidth;
        final columns = width >= 1100
            ? 4
            : width >= 760
                ? 3
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, index) {
            final p = products[index];
            return ProductCard(product: p, onTap: () => onTap(p));
          },
        );
      },
    );
  }
}
