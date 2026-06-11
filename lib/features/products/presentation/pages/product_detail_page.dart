import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_gradient_header.dart';
import '../../../../core/widgets/app_primary_action_bar.dart';
import '../../domain/entities/product.dart';
import '../controllers/product_detail_controller.dart';

/// Detalle de producto — pantalla read-only con FAB "Editar".
///
/// El tap en una card de la lista de productos llega acá (no al form de
/// edición directo). Desde acá el operario decide si quiere modificar el
/// producto o solo verlo.
class ProductDetailPage extends GetView<ProductDetailController> {
  const ProductDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Obx(() {
        final product = controller.product.value;
        if (controller.isLoading.value && product == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value.isNotEmpty && product == null) {
          return SafeArea(
            child: AppErrorState(
              message: controller.errorMessage.value,
              onRetry: controller.reload,
            ),
          );
        }
        if (product == null) {
          return const SafeArea(
            child: Center(
              child: Text(
                'No se encontró el producto',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }
        return SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: controller.reload,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                _Header(product: product),
                if (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                  _ImageBanner(url: product.imageUrl!),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BasicInfoSection(product: product),
                      const SizedBox(height: 14),
                      if (product.description.trim().isNotEmpty) ...[
                        _DescriptionSection(text: product.description),
                        const SizedBox(height: 14),
                      ],
                      _PricingSection(product: product),
                      const SizedBox(height: 14),
                      if (product.trackInventory) ...[
                        _InventorySection(product: product),
                        const SizedBox(height: 14),
                      ],
                      if (product.variants.isNotEmpty) ...[
                        _VariantsSection(variants: product.variants),
                        const SizedBox(height: 14),
                      ],
                      if (product.modifierGroups.isNotEmpty) ...[
                        _ModifierGroupsSection(
                          groups: product.modifierGroups,
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (product.tags.isNotEmpty ||
                          product.allergens.isNotEmpty) ...[
                        _TagsAllergensSection(product: product),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
      bottomNavigationBar: Obx(() {
        final product = controller.product.value;
        if (product == null) return const SizedBox.shrink();
        return AppPrimaryActionBar(
          label: 'Editar producto',
          icon: Icons.edit,
          onPressed: () async {
            final result =
                await Get.toNamed('/products/edit', arguments: product);
            if (result != null) controller.reload();
          },
        );
      }),
    );
  }
}

class _Header extends StatelessWidget {
  final Product product;
  const _Header({required this.product});

  @override
  Widget build(BuildContext context) {
    return AppGradientHeader(
      title: product.name,
      subtitle: product.sku != null && product.sku!.isNotEmpty
          ? 'SKU: ${product.sku}'
          : 'Detalle del producto',
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
      ),
      hero: AppKpiHero(
        icon: Icons.attach_money,
        label: 'Precio base',
        value: CurrencyFormatter.format(product.basePrice),
        hint: product.preparationTime > 0
            ? '${product.preparationTime} min de preparación'
            : null,
      ),
      chips: [
        AppKpiChip(
          icon: product.isAvailable
              ? Icons.check_circle_outline
              : Icons.cancel_outlined,
          label: 'Estado',
          value: product.isAvailable ? 'Disponible' : 'Pausado',
        ),
        AppKpiChip(
          icon: Icons.shopping_cart_outlined,
          label: 'Vendidos',
          value: product.totalSold.toString(),
        ),
        AppKpiChip(
          icon: Icons.layers,
          label: 'Variantes',
          value: product.variants.length.toString(),
        ),
        AppKpiChip(
          icon: Icons.tune,
          label: 'Grupos',
          value: product.modifierGroups.length.toString(),
        ),
      ],
    );
  }
}

class _ImageBanner extends StatelessWidget {
  final String url;
  const _ImageBanner({required this.url});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: AppColors.background,
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image_outlined,
                size: 48,
                color: AppColors.textHint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final Widget child;
  const _Section({
    required this.icon,
    required this.accent,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accent, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _BasicInfoSection extends StatelessWidget {
  final Product product;
  const _BasicInfoSection({required this.product});

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.info_outline,
      accent: AppColors.primary,
      title: 'Información básica',
      child: Column(
        children: [
          _InfoRow(
            label: 'SKU',
            value: product.sku ?? '—',
            icon: Icons.qr_code,
          ),
          _InfoRow(
            label: 'Tiempo de preparación',
            value: product.preparationTime > 0
                ? '${product.preparationTime} min'
                : '—',
            icon: Icons.timer_outlined,
          ),
          _InfoRow(
            label: 'Total vendido',
            value: '${product.totalSold} unidades',
            icon: Icons.shopping_cart_outlined,
          ),
          _InfoRow(
            label: 'Total facturado',
            value: CurrencyFormatter.format(product.totalRevenue),
            icon: Icons.attach_money,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _DescriptionSection extends StatelessWidget {
  final String text;
  const _DescriptionSection({required this.text});

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.description_outlined,
      accent: AppColors.info,
      title: 'Descripción',
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
          height: 1.45,
        ),
      ),
    );
  }
}

class _PricingSection extends StatelessWidget {
  final Product product;
  const _PricingSection({required this.product});

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.attach_money,
      accent: AppColors.success,
      title: 'Precios',
      child: Column(
        children: [
          _InfoRow(
            label: 'Precio base',
            value: CurrencyFormatter.format(product.basePrice),
            icon: Icons.sell_outlined,
            valueBold: true,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _InventorySection extends StatelessWidget {
  final Product product;
  const _InventorySection({required this.product});

  @override
  Widget build(BuildContext context) {
    final stock = product.currentStock ?? 0;
    final minAlert = product.minStockAlert ?? 0;
    final isLow = stock <= minAlert;
    final isOut = stock <= 0;
    final color = isOut
        ? AppColors.error
        : (isLow ? AppColors.warning : AppColors.success);
    final label = isOut ? 'Agotado' : (isLow ? 'Stock bajo' : 'En stock');
    return _Section(
      icon: Icons.inventory_2_outlined,
      accent: AppColors.info,
      title: 'Inventario',
      child: Column(
        children: [
          _InfoRow(
            label: 'Stock actual',
            value: stock.toString(),
            icon: Icons.inventory,
            valueColor: color,
            valueBold: true,
          ),
          _InfoRow(
            label: 'Alerta mínima',
            value: minAlert.toString(),
            icon: Icons.warning_amber_outlined,
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  isOut
                      ? Icons.cancel_outlined
                      : (isLow ? Icons.warning_amber : Icons.check_circle),
                  color: color,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VariantsSection extends StatelessWidget {
  final List<dynamic> variants;
  const _VariantsSection({required this.variants});

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.layers,
      accent: AppColors.warning,
      title: 'Variantes (${variants.length})',
      child: Column(
        children: variants.map((v) {
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    v.name as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if ((v.priceModifier as double) != 0)
                  Text(
                    '${(v.priceModifier as double) > 0 ? "+" : ""}${CurrencyFormatter.format(v.priceModifier as double)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: (v.priceModifier as double) > 0
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ModifierGroupsSection extends StatelessWidget {
  final List<dynamic> groups;
  const _ModifierGroupsSection({required this.groups});

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.tune,
      accent: AppColors.primary,
      title: 'Grupos de modificadores (${groups.length})',
      child: Column(
        children: groups.map((g) {
          final modifiers = g.modifiers as List;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        g.name as String,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (g.isRequired as bool)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Obligatorio',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                  ],
                ),
                if (modifiers.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: modifiers
                        .map<Widget>((m) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                m.name as String,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TagsAllergensSection extends StatelessWidget {
  final Product product;
  const _TagsAllergensSection({required this.product});

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.label_outline,
      accent: AppColors.warning,
      title: 'Etiquetas y alérgenos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (product.tags.isNotEmpty) ...[
            const Text(
              'Etiquetas',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: product.tags.map((t) => _Pill(label: t, color: AppColors.info)).toList(),
            ),
            const SizedBox(height: 10),
          ],
          if (product.allergens.isNotEmpty) ...[
            const Text(
              'Alérgenos',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: product.allergens
                  .map((a) => _Pill(label: a, color: AppColors.error))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool valueBold;
  final Color? valueColor;
  final bool isLast;
  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueBold = false,
    this.valueColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: valueBold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
