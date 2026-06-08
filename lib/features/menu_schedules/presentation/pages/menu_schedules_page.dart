import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../data/models/menu_schedule_grid_item.dart';
import '../controllers/menu_schedules_controller.dart';

/// Pantalla "Menú del día" — admin programa qué productos están
/// disponibles en self-order (QR) para una fecha.
///
/// Layout: header con date picker + contador, filtros (búsqueda +
/// status chip), grilla de productos con switch por item, botón
/// "Programar todo" / "Limpiar".
class MenuSchedulesPage extends GetView<MenuSchedulesController> {
  const MenuSchedulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Menú del día'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh),
            onPressed: controller.fetch,
          ),
          PopupMenuButton<String>(
            tooltip: 'Más acciones',
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'program-all',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.playlist_add_check),
                  title: Text('Programar todos los productos'),
                  subtitle: Text('Para la fecha seleccionada'),
                ),
              ),
              PopupMenuItem(
                value: 'replace',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.restart_alt),
                  title: Text('Reemplazar (reset)'),
                  subtitle: Text('Borra existentes y crea de cero'),
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.layers_clear),
                  title: Text('Limpiar día'),
                  subtitle: Text('Quita todos del menú'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _DateAndStats(controller: controller),
            _FiltersBar(controller: controller),
            const Divider(height: 1),
            Expanded(child: _ProductGrid(controller: controller)),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String value) async {
    switch (value) {
      case 'program-all':
        final ok = await _confirm(
          context,
          'Programar todos los productos',
          'Esto agrega al menú de hoy todos los productos disponibles '
              'que aún no estaban programados.',
          confirmText: 'Programar',
        );
        if (ok) await controller.programAll();
        break;
      case 'replace':
        final ok = await _confirm(
          context,
          'Reemplazar menú del día',
          '⚠️ Esto BORRA todas las programaciones del día y las recrea '
              'con todos los productos disponibles. ¿Continuar?',
          confirmText: 'Reemplazar',
          destructive: true,
        );
        if (ok) await controller.programAll(replace: true);
        break;
      case 'clear':
        final ok = await _confirm(
          context,
          'Limpiar día',
          'Desactiva todos los productos del menú del día. Podés volver '
              'a activarlos uno por uno.',
          confirmText: 'Limpiar',
          destructive: true,
        );
        if (ok) await controller.clearAll();
        break;
    }
  }

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String message, {
    required String confirmText,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                  )
                : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ---------------------------------------------------------------------
// Header con date picker + contador
// ---------------------------------------------------------------------
class _DateAndStats extends StatelessWidget {
  final MenuSchedulesController controller;
  const _DateAndStats({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Obx(() => InkWell(
                  onTap: () => _pickDate(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatDate(controller.selectedDate.value),
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down,
                            size: 18, color: AppColors.primary),
                      ],
                    ),
                  ),
                )),
          ),
          const SizedBox(width: 12),
          Obx(() => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${controller.programmedCount}/${controller.totalCount}',
                      style: TextStyle(
                        color: AppColors.accentDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'en menú',
                      style: TextStyle(
                        color: AppColors.accentDark,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final current = DateTime.tryParse(controller.selectedDate.value) ??
        DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) {
      final ymd = '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
      await controller.setDate(ymd);
    }
  }

  String _formatDate(String ymd) {
    final dt = DateTime.tryParse(ymd);
    if (dt == null) return ymd;
    final today = DateTime.now();
    final isToday = dt.year == today.year &&
        dt.month == today.month &&
        dt.day == today.day;
    final tomorrow = today.add(const Duration(days: 1));
    final isTomorrow = dt.year == tomorrow.year &&
        dt.month == tomorrow.month &&
        dt.day == tomorrow.day;
    final pretty =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    if (isToday) return 'Hoy · $pretty';
    if (isTomorrow) return 'Mañana · $pretty';
    return pretty;
  }
}

// ---------------------------------------------------------------------
// Filtros: búsqueda + status chips
// ---------------------------------------------------------------------
class _FiltersBar extends StatelessWidget {
  final MenuSchedulesController controller;
  const _FiltersBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: 'Buscar producto o categoría',
              isDense: true,
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => controller.search.value = v,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: Obx(() => ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _StatusChip(
                      label: 'Todos',
                      selected: controller.statusFilter.value == 'all',
                      onTap: () => controller.statusFilter.value = 'all',
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(
                      label: 'En el menú',
                      icon: Icons.check_circle,
                      color: AppColors.accent,
                      selected:
                          controller.statusFilter.value == 'programmed',
                      onTap: () =>
                          controller.statusFilter.value = 'programmed',
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(
                      label: 'Fuera del menú',
                      icon: Icons.remove_circle_outline,
                      color: Colors.grey,
                      selected: controller.statusFilter.value == 'not',
                      onTap: () => controller.statusFilter.value = 'not',
                    ),
                  ],
                )),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    this.icon,
    this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c : c.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withValues(alpha: selected ? 1 : 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : c,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : c,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Grilla de productos con switch por item
// ---------------------------------------------------------------------
class _ProductGrid extends StatelessWidget {
  final MenuSchedulesController controller;
  const _ProductGrid({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.loading.value && controller.items.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.error.value != null && controller.items.isEmpty) {
        return _ErrorState(
          message: controller.error.value!,
          onRetry: controller.fetch,
        );
      }
      final list = controller.visible;
      if (list.isEmpty) {
        return _EmptyState(
          totalProducts: controller.totalCount,
          search: controller.search.value,
          statusFilter: controller.statusFilter.value,
        );
      }
      return RefreshIndicator(
        onRefresh: controller.fetch,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _ProductRow(
            item: list[i],
            controller: controller,
          ),
        ),
      );
    });
  }
}

class _ProductRow extends StatelessWidget {
  final MenuScheduleGridItem item;
  final MenuSchedulesController controller;

  const _ProductRow({required this.item, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isProcessing =
        controller.processingProductIds.contains(item.product.id);
    final on = item.isProgrammed;

    return Material(
      color: on
          ? AppColors.accent.withValues(alpha: 0.06)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isProcessing ? null : () => controller.toggle(item),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: on
                  ? AppColors.accent.withValues(alpha: 0.3)
                  : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              // Imagen del producto (o placeholder).
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: item.product.imageUrl != null
                      ? Image.network(
                          item.product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.product.categoryName != null)
                      Text(
                        item.product.categoryName!,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(item.product.basePrice),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (isProcessing)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch.adaptive(
                  value: on,
                  activeThumbColor: AppColors.accent,
                  onChanged: (_) => controller.toggle(item),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Icon(
        Icons.restaurant,
        color: Colors.grey.shade400,
        size: 24,
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Estados auxiliares
// ---------------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  final int totalProducts;
  final String search;
  final String statusFilter;

  const _EmptyState({
    required this.totalProducts,
    required this.search,
    required this.statusFilter,
  });

  @override
  Widget build(BuildContext context) {
    final hasFilters = search.isNotEmpty || statusFilter != 'all';

    if (totalProducts == 0) {
      // Tenant todavía no tiene productos creados.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 60,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 14),
              const Text(
                'No hay productos creados',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Creá productos primero en el módulo de Productos.',
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters ? Icons.search_off : Icons.fact_check_outlined,
              size: 60,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 14),
            Text(
              hasFilters
                  ? 'Sin resultados con los filtros'
                  : 'Listo para configurar',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'Probá quitando filtros.'
                  : 'Activá productos individualmente con el switch, o usá el menú '
                      'arriba a la derecha para programar todos a la vez.',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber, size: 56, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
