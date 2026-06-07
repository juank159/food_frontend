import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/inventory_movement.dart';
import '../controllers/inventory_detail_controller.dart';

/// Inventory Detail Page — pantalla de detalle de un item de inventario.
///
/// Estructura (mismo lenguaje visual que `customer_detail_page` y
/// `category_detail_page`):
///
///   - `AppGradientHeader` con back, título "Detalle de inventario",
///     subtítulo con el nombre del producto, y CTA "Ajustar" como trailing.
///   - `AppKpiHero` con el stock actual destacado, color según estado.
///   - Sección "Información del producto": SKU, categoría, precio, disponibilidad.
///   - Sección "Estado del stock": stock vs mínimo + barra de progreso
///     con código de colores (verde / ámbar / rojo).
///   - Sección "Configuración": tracking on/off (read-only) + min_stock_alert.
///   - Sección "Histórico de ajustes": placeholder porque el backend no expone
///     el endpoint `GET /products/:id/inventory-history` todavía.
class InventoryDetailPage extends GetView<InventoryDetailController> {
  const InventoryDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Obx(() {
          if (controller.isLoading && controller.item.value == null) {
            return Column(
              children: [
                _buildSkeletonHeader(),
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }
          if (controller.hasError) {
            return Column(
              children: [
                _buildSkeletonHeader(),
                Expanded(
                  child: AppErrorState(
                    message: controller.errorMessage.value,
                    onRetry: controller.refresh,
                  ),
                ),
              ],
            );
          }
          final item = controller.item.value;
          if (item == null) return const SizedBox.shrink();
          return _buildLoaded(item);
        }),
      ),
    );
  }

  // ─────────────────────────── Header ───────────────────────────

  /// Header simple para los estados loading/error — sin hero ni chips, así
  /// la transición a "loaded" no salta visualmente.
  Widget _buildSkeletonHeader() {
    return AppGradientHeader(
      title: 'Detalle de inventario',
      subtitle: 'Cargando producto…',
      leading: _BackButton(),
    );
  }

  Widget _buildHeader(InventoryItem item) {
    final color = _statusColor(item);
    return AppGradientHeader(
      title: 'Detalle de inventario',
      subtitle: item.name,
      leading: _BackButton(),
      trailing: _AdjustButton(onTap: controller.goToAdjustment),
      hero: AppKpiHero(
        icon: Icons.inventory_2_outlined,
        label: _heroLabel(item),
        value: _heroValue(item),
        hint: _heroHint(item, color),
      ),
    );
  }

  // ─────────────────────────── Body ───────────────────────────

  Widget _buildLoaded(InventoryItem item) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: controller.refresh,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(item),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAlertBanner(item),
                _buildInfoSection(item),
                const SizedBox(height: 16),
                _buildStockSection(item),
                const SizedBox(height: 16),
                _buildConfigSection(item),
                const SizedBox(height: 16),
                _buildHistorySection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── Alert banner ───────────────────────────

  /// Banner inline arriba de las secciones cuando el producto está agotado
  /// o con stock bajo. Se oculta cuando todo está sano.
  Widget _buildAlertBanner(InventoryItem item) {
    if (!item.trackInventory) return const SizedBox.shrink();
    if (item.isOutOfStock) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _AlertBanner(
          icon: Icons.remove_circle_outline,
          color: AppColors.error,
          title: 'Producto agotado',
          message:
              'No quedan unidades disponibles. Ajustá el stock cuando recibas mercadería.',
        ),
      );
    }
    if (item.isLowStock) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _AlertBanner(
          icon: Icons.warning_amber_rounded,
          color: AppColors.warning,
          title: 'Stock bajo',
          message:
              'El nivel actual está por debajo del umbral configurado. Considerá reabastecer pronto.',
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // ─────────────────────────── Info section ───────────────────────────

  Widget _buildInfoSection(InventoryItem item) {
    return _DetailSection(
      title: 'Información del producto',
      icon: Icons.info_outline,
      accent: AppColors.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(
            icon: Icons.qr_code_2,
            label: 'SKU',
            value: (item.sku == null || item.sku!.isEmpty)
                ? '—'
                : item.sku!,
          ),
          const Divider(height: 16, color: AppColors.divider),
          _InfoRow(
            icon: Icons.category_outlined,
            label: 'Categoría',
            value: (item.categoryName == null || item.categoryName!.isEmpty)
                ? '—'
                : item.categoryName!,
          ),
          const Divider(height: 16, color: AppColors.divider),
          _InfoRow(
            icon: Icons.payments_outlined,
            label: 'Precio',
            value: item.basePrice == null
                ? '—'
                : CurrencyFormatter.format(item.basePrice!),
          ),
          const Divider(height: 16, color: AppColors.divider),
          _InfoRow(
            icon: item.isAvailable
                ? Icons.check_circle_outline
                : Icons.do_not_disturb_on_outlined,
            label: 'Disponibilidad',
            value: item.isAvailable
                ? 'Disponible para venta'
                : 'No disponible',
            valueColor:
                item.isAvailable ? AppColors.success : AppColors.error,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── Stock section ───────────────────────────

  Widget _buildStockSection(InventoryItem item) {
    final color = _statusColor(item);
    return _DetailSection(
      title: 'Estado del stock',
      icon: Icons.inventory_outlined,
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!item.trackInventory)
            _InlineEmpty(
              icon: Icons.layers_clear_outlined,
              message:
                  'Este producto no trackea inventario. Activá el tracking desde el form de Productos para empezar a controlar stock.',
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Stock actual',
                    value: (item.currentStock ?? 0).toString(),
                    color: color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    label: 'Mínimo',
                    value: item.minStockAlert?.toString() ?? '—',
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _StockProgressBar(
              ratio: controller.stockRatio,
              color: color,
              label: _progressLabel(item, controller.stockRatio),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────── Config section ───────────────────────────

  Widget _buildConfigSection(InventoryItem item) {
    return _DetailSection(
      title: 'Configuración',
      icon: Icons.tune,
      accent: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Switch read-only: visualmente igual a un Switch real, pero al
          // tocarlo redirige al form del producto para editar el flag.
          _ReadOnlySwitchTile(
            title: 'Trackeo de inventario',
            subtitle: item.trackInventory
                ? 'Activo — el sistema descuenta stock con cada venta.'
                : 'Inactivo — este producto no controla stock.',
            value: item.trackInventory,
            onTap: _onEditConfig,
          ),
          const Divider(height: 16, color: AppColors.divider),
          _InfoRow(
            icon: Icons.warning_amber_rounded,
            label: 'Umbral de alerta',
            value: item.minStockAlert == null
                ? 'Sin configurar'
                : '${item.minStockAlert} unidades',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _onEditConfig,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Editar en Productos'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── History section ───────────────────────────

  /// Histórico de movimientos del producto. Cada fila muestra el delta
  /// (+/-), el stock resultante, la razón, el usuario y la fecha. Los
  /// movimientos vienen ordenados desde el backend (más recientes
  /// primero) y se cargan en paralelo con el item via `loadHistory()`.
  Widget _buildHistorySection() {
    return Obx(() {
      final movements = controller.history;
      final isLoading = controller.isLoadingHistory.value;

      Widget child;
      if (isLoading && movements.isEmpty) {
        child = const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      } else if (movements.isEmpty) {
        child = const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: AppEmptyState(
            icon: Icons.history_toggle_off,
            title: 'Sin movimientos aún',
            message:
                'Cuando ajustes el stock o el producto se consuma en órdenes, los movimientos aparecerán acá.',
            accent: AppColors.textSecondary,
          ),
        );
      } else {
        child = Column(
          children: [
            for (final m in movements) _MovementRow(movement: m),
          ],
        );
      }

      return _DetailSection(
        title: 'Histórico de ajustes',
        icon: Icons.history,
        accent: AppColors.textSecondary,
        child: child,
      );
    });
  }

  // ─────────────────────────── Acciones ───────────────────────────

  Future<void> _onEditConfig() async {
    final item = controller.item.value;
    if (item == null) return;
    // Convención del módulo de Productos: la ruta `/products/edit` recibe
    // el producto en `arguments`. Como acá tenemos un `InventoryItem` y no
    // un `Product` completo, mandamos sólo el id — el form del producto se
    // encarga de hidratar lo que falte. Si el backend devuelve un producto
    // editado, recargamos para ver los cambios.
    final result = await Get.toNamed(
      AppRoutes.buildEditProduct(item.id),
    );
    if (result != null) {
      await controller.refresh();
    }
  }

  // ─────────────────────────── Helpers ───────────────────────────

  /// Color principal del estado del item: verde sano, ámbar bajo, rojo
  /// agotado, gris cuando no trackea.
  Color _statusColor(InventoryItem item) {
    if (!item.trackInventory) return AppColors.textHint;
    if (item.isOutOfStock) return AppColors.error;
    if (item.isLowStock) return AppColors.warning;
    return AppColors.success;
  }

  String _heroLabel(InventoryItem item) {
    if (!item.trackInventory) return 'Sin tracking';
    if (item.isOutOfStock) return 'Stock agotado';
    if (item.isLowStock) return 'Stock bajo';
    return 'Stock disponible';
  }

  String _heroValue(InventoryItem item) {
    if (!item.trackInventory) return '—';
    return (item.currentStock ?? 0).toString();
  }

  String? _heroHint(InventoryItem item, Color color) {
    if (!item.trackInventory) {
      return 'Activá el tracking desde Productos';
    }
    if (item.minStockAlert == null) return 'Sin umbral mínimo configurado';
    return 'Mínimo configurado: ${item.minStockAlert}';
  }

  String _progressLabel(InventoryItem item, double? ratio) {
    if (ratio == null) {
      // Sin umbral o stock 0 sin tracking — texto neutro.
      if (!item.trackInventory) return 'Tracking desactivado';
      if ((item.minStockAlert ?? 0) <= 0) {
        return 'Configurá un umbral mínimo para ver el progreso.';
      }
      return '—';
    }
    final pct = (ratio * 100).clamp(0, 999).round();
    if (ratio < 0.5) return 'Crítico — $pct% del mínimo';
    if (ratio < 1.5) return 'Atención — $pct% del mínimo';
    return 'Saludable — $pct% del mínimo';
  }
}

// ─────────────────────────── Sub-widgets ───────────────────────────

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.back<void>(),
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
    );
  }
}

/// Botón "Ajustar" en la trailing del header. Translúcido sobre el
/// gradient — coincide con el lenguaje de los otros detail pages.
class _AdjustButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AdjustButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune, color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text(
                'Ajustar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sección genérica del detalle: card con título + icono + children.
/// Replica el "look" de `AppFormSection-lite` que usa `customer_detail_page`.
class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? accent;
  final Widget child;

  const _DetailSection({
    required this.title,
    required this.icon,
    this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.primary;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: valueColor ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.0,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de progreso del stock relativo al umbral mínimo. La capamos a
/// 200% para que el visual no se rompa cuando el stock es 10× el mínimo.
class _StockProgressBar extends StatelessWidget {
  final double? ratio;
  final Color color;
  final String label;

  const _StockProgressBar({
    required this.ratio,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    // Sin ratio: barra plana gris + label informativo.
    final r = ratio;
    final clamped = r == null ? 0.0 : (r / 2.0).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(
            children: [
              Container(
                height: 10,
                color: AppColors.background,
              ),
              FractionallySizedBox(
                widthFactor: clamped,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              // Marca del 50% (mínimo configurado) — referencia visual.
              if (r != null)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    // 50% del ancho total = ratio 1.0 (mínimo).
                    widthFactor: 0.5,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 2,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: r == null ? AppColors.textHint : color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Switch read-only que parece un Switch real — el usuario lo ve como
/// "leído desde el producto". Al tocarlo se va al form del producto.
class _ReadOnlySwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final VoidCallback onTap;

  const _ReadOnlySwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = value ? AppColors.success : AppColors.textHint;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                value ? Icons.toggle_on : Icons.toggle_off,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textHint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner inline para alertas críticas (agotado / bajo).
class _AlertBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;

  const _AlertBanner({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
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

class _InlineEmpty extends StatelessWidget {
  final IconData icon;
  final String message;

  const _InlineEmpty({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.textHint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila para un movimiento individual del histórico de inventario.
///
/// Layout: [icono delta] [reason · timestamp · usuario] [delta + stock_after]
/// El icono y color cambia según el tipo de movimiento — verde para
/// ingresos, rojo para egresos, ámbar para merma.
class _MovementRow extends StatelessWidget {
  final InventoryMovement movement;
  const _MovementRow({required this.movement});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(movement);
    final icon = _iconFor(movement);
    final deltaText = movement.delta > 0
        ? '+${movement.delta}'
        : movement.delta.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement.reason.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitleFor(movement),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (movement.notes != null && movement.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    movement.notes!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                deltaText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                'Stock: ${movement.stockAfter}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _colorFor(InventoryMovement m) {
    if (m.reason == InventoryMovementReason.waste) return AppColors.warning;
    if (m.delta > 0) return AppColors.success;
    return AppColors.error;
  }

  IconData _iconFor(InventoryMovement m) {
    switch (m.reason) {
      case InventoryMovementReason.adjustment:
        return Icons.tune;
      case InventoryMovementReason.orderConsume:
        return Icons.shopping_cart_outlined;
      case InventoryMovementReason.orderRestore:
        return Icons.undo;
      case InventoryMovementReason.purchase:
        return Icons.local_shipping_outlined;
      case InventoryMovementReason.waste:
        return Icons.delete_outline;
    }
  }

  String _subtitleFor(InventoryMovement m) {
    final ts = _formatRelative(m.createdAt);
    final actor = m.userName ?? 'Sistema';
    return '$ts · $actor';
  }

  String _formatRelative(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'hace un momento';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'hace ${diff.inDays} d';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
