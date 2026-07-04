import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/navigation_service.dart';
import '../../../../core/utils/app_dialog.dart';
import '../../../../core/utils/date_period.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/app_filter_chip.dart';
import '../../../../core/widgets/app_primary_action_bar.dart';
import '../../../tab_sessions/presentation/controllers/open_tabs_controller.dart';
import '../../../tab_sessions/presentation/widgets/open_tabs_view.dart';
import '../../../../core/routes/app_routes.dart';
import '../controllers/orders_controller.dart';
import '../widgets/order_card.dart';

/// Pantalla de Órdenes — diseño moderno tipo dashboard de POS:
///
///   1) Header con gradiente: ventas del día + KPIs rápidos (activas,
///      pendientes, en prep, listas).
///   2) Segmented chips inline para filtrar por estado (sin modal).
///   3) Lista con OrderCards rediseñados.
///   4) Empty state con ilustración y CTA prominente.
///   5) Acción primaria "Nueva orden":
///      - Sin órdenes: `AppPrimaryActionBar` en bottomNavigationBar
///        (ancho completo, sin truncado, mismo lenguaje en todas las
///        plataformas).
///      - Con órdenes: FAB simple solo con icono (no extended) —
///        ocupa menos espacio sobre la lista y respeta la regla del
///        proyecto de no usar FAB.extended con label.
class OrdersPage extends GetView<OrdersController> {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(controller: controller),
            _ViewToggle(controller: controller),
            Expanded(
              child: Obx(() {
                // Segmento "Cuentas abiertas" — embebe la MISMA vista que
                // la pantalla dedicada, así no hay que saltar de pantalla.
                if (controller.mainView.value == 1) {
                  return const OpenTabsView();
                }
                return Column(
                  children: [
                    _OrdersFilterBar(controller: controller),
                    const SizedBox(height: 8),
                    Expanded(child: _OrdersList(controller: controller)),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
      // Cuando ya hay órdenes mostramos solo un FAB con icono (sin
      // label) para no robar espacio sobre la lista. Cuando NO hay
      // órdenes, la acción primaria se muestra como una barra ancha en
      // el bottomNavigationBar — más prominente y sin riesgo de
      // overflow del label.
      floatingActionButton: Obx(() {
        // En el segmento "Cuentas abiertas" el FAB de "Nueva orden" no
        // aplica — esa vista tiene su propio botón "Abrir cuenta libre".
        if (controller.mainView.value == 1) return const SizedBox.shrink();
        if (!controller.hasOrders) return const SizedBox.shrink();
        return FloatingActionButton(
          // heroTag único — el HomeScreen monta varias pantallas con FAB
          // dentro del mismo IndexedStack (Órdenes + Mesas). Sin
          // heroTag explícito, Flutter usa "<default FloatingActionButton tag>"
          // en cada uno y al cambiar de tab tira: "multiple heroes that
          // share the same tag within a subtree".
          heroTag: 'orders-page-fab',
          onPressed: () => NavigationService.toCreateOrder(),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          tooltip: 'Nueva orden',
          child: const Icon(Icons.add),
        );
      }),
      bottomNavigationBar: Obx(() {
        // Solo en el segmento de Órdenes y cuando no hay órdenes.
        if (controller.mainView.value == 1) return const SizedBox.shrink();
        if (controller.hasOrders || controller.isLoading.value) {
          return const SizedBox.shrink();
        }
        return AppPrimaryActionBar(
          label: 'Nueva orden',
          icon: Icons.add,
          onPressed: () => NavigationService.toCreateOrder(),
        );
      }),
    );
  }
}

// ─────────────────────────── View toggle ──────────────────────────────

/// Segmentado "Órdenes | Cuentas abiertas" — unifica las dos vistas en
/// una sola pantalla. El segundo segmento muestra el conteo de cuentas
/// abiertas en vivo para que el operario sepa cuántas hay sin entrar.
class _ViewToggle extends StatelessWidget {
  final OrdersController controller;
  const _ViewToggle({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Obx(() {
        final view = controller.mainView.value;
        // Conteo reactivo de cuentas abiertas (instancia el controller si
        // hace falta — su onInit dispara el load).
        final openCount = Get.isRegistered<OpenTabsController>()
            ? Get.find<OpenTabsController>().sessions.length
            : 0;
        return Row(
          children: [
            Expanded(
              child: _segment(
                label: 'Órdenes',
                icon: Icons.receipt_long_outlined,
                selected: view == 0,
                onTap: () => controller.switchMainView(0),
              ),
            ),
            Expanded(
              child: _segment(
                label: openCount > 0
                    ? 'Cuentas abiertas ($openCount)'
                    : 'Cuentas abiertas',
                icon: Icons.account_balance_wallet_outlined,
                selected: view == 1,
                onTap: () => controller.switchMainView(1),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _segment({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────── Header ───────────────────────────────

class _Header extends StatelessWidget {
  final OrdersController controller;
  const _Header({required this.controller});

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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila única: título + total del día inline (antes el total era
          // una tarjeta grande aparte que comía mucho alto) + refrescar.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Órdenes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              Obx(() => Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Ventas hoy',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                      Text(
                        CurrencyFormatter.format(controller.totalSalesToday),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  )),
              // "Por cobrar": ícono con badge del conteo de órdenes con
              // saldo pendiente (sin filtro de fecha). Solo aparece si hay.
              Obx(() {
                final n = controller.unpaidCount;
                if (n == 0) return const SizedBox(width: 4);
                return IconButton(
                  onPressed: () => Get.toNamed(AppRoutes.unpaidOrders),
                  tooltip: 'Por cobrar',
                  visualDensity: VisualDensity.compact,
                  icon: Badge(
                    label: Text('$n'),
                    backgroundColor: AppColors.error,
                    child: const Icon(Icons.request_quote_outlined,
                        color: Colors.white, size: 22),
                  ),
                );
              }),
              IconButton(
                onPressed: controller.refreshOrders,
                tooltip: 'Refrescar',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Stats secundarios — chips compactos sobre el gradient.
          Obx(() => Row(
                children: [
                  Expanded(
                    child: _StatChip(
                      label: 'Activas',
                      value: controller.totalActiveOrders,
                      icon: Icons.pending_actions,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatChip(
                      label: 'Pendientes',
                      value: controller.totalPendingOrders,
                      icon: Icons.schedule,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatChip(
                      label: 'En prep.',
                      value: controller.totalPreparingOrders,
                      icon: Icons.restaurant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatChip(
                      label: 'Listas',
                      value: controller.totalReadyOrders,
                      icon: Icons.check_circle_outline,
                    ),
                  ),
                ],
              )),
        ],
      ),
    );
  }

}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(height: 3),
          Text(
            value.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Filter bar (compacto + reutilizable) ───────────────────────

/// Configura el `AppFilterBar` reutilizable para la pantalla de órdenes:
/// búsqueda + período (default Hoy) + filtros avanzados (estado / tipo /
/// pago) en un sheet, con chips de resumen removibles. Ocupa UNA fila
/// salvo que haya filtros avanzados activos (ahí suma la fila de chips).
class _OrdersFilterBar extends StatefulWidget {
  final OrdersController controller;
  const _OrdersFilterBar({required this.controller});

  @override
  State<_OrdersFilterBar> createState() => _OrdersFilterBarState();
}

class _OrdersFilterBarState extends State<_OrdersFilterBar> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.controller.searchQuery.value);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  /// Etiqueta del pill cuando hay un rango personalizado, ej "12/06 – 14/06".
  String? _customLabel() {
    final c = widget.controller;
    if (c.datePeriod.value != DatePeriod.custom) return null;
    final s = c.startDate.value;
    final e = c.endDate.value;
    if (s == null && e == null) return null;
    final sStr = s != null ? '${_two(s.day)}/${_two(s.month)}' : '—';
    final eStr = e != null ? '${_two(e.day)}/${_two(e.month)}' : '—';
    return '$sStr – $eStr';
  }

  Future<void> _pickCustomRange() async {
    final c = widget.controller;
    final now = DateTime.now();
    final current = (c.startDate.value != null && c.endDate.value != null)
        ? DateTimeRange(start: c.startDate.value!, end: c.endDate.value!)
        : null;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: current,
      helpText: 'Seleccioná un rango',
      saveText: 'Aplicar',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      c.setDatePeriod(
        DatePeriod.custom,
        customStart: picked.start,
        customEnd: picked.end,
      );
    }
  }

  /// Chips de resumen de los filtros avanzados activos (estado/activas,
  /// tipo, pago). Cada uno se quita con un toque.
  List<ActiveFilterChipData> _activeChips() {
    final c = widget.controller;
    final chips = <ActiveFilterChipData>[];

    if (c.showOnlyActive.value) {
      chips.add(ActiveFilterChipData(
        label: 'Activas',
        onRemove: c.toggleActiveFilter,
      ));
    } else if (c.filterStatus.value != null) {
      final s = c.filterStatus.value!;
      chips.add(ActiveFilterChipData(
        label: s.displayName,
        onRemove: () => c.filterByStatus(null),
      ));
    }

    if (c.filterOrderType.value != null) {
      final t = c.filterOrderType.value!;
      chips.add(ActiveFilterChipData(
        label: t.displayName,
        onRemove: () => c.filterByOrderType(null),
      ));
    }

    if (c.filterPaymentStatus.value != null) {
      final p = c.filterPaymentStatus.value!;
      chips.add(ActiveFilterChipData(
        label: p.displayName,
        color: paymentStatusColor(p),
        onRemove: () => c.filterByPaymentStatus(null),
      ));
    }

    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Obx(() {
      return AppFilterBar(
        searchController: _search,
        searchHint: 'Buscar # orden, mesa, cliente, teléfono…',
        onSearchChanged: c.setSearchQuery,
        period: c.datePeriod.value,
        onPeriodSelected: (p) => c.setDatePeriod(p),
        onPickCustomRange: _pickCustomRange,
        customRangeLabel: _customLabel(),
        activeFilterCount: c.advancedFilterCount,
        onOpenFilters: () => _openFiltersSheet(context, c),
        activeChips: _activeChips(),
        onClearAll: c.clearAdvancedFilters,
      );
    });
  }
}

void _openFiltersSheet(BuildContext context, OrdersController controller) {
  AppDialog.bottomSheet(
    _FiltersSheet(controller: controller),
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
}

/// Color de acento por estado de pago — verde pagado, ámbar pendiente,
/// rojo fallido, gris reembolsado. Da lectura instantánea en chips.
Color paymentStatusColor(PaymentStatus ps) {
  switch (ps) {
    case PaymentStatus.completed:
      return AppColors.success;
    case PaymentStatus.pending:
      return AppColors.warning;
    case PaymentStatus.failed:
      return AppColors.error;
    case PaymentStatus.refunded:
      return AppColors.textSecondary;
  }
}

/// Sheet de filtros avanzados: estado, tipo de orden y estado de pago.
/// Los chips aplican en vivo (Obx); ofrece "Limpiar" + "Listo".
class _FiltersSheet extends StatelessWidget {
  final OrdersController controller;
  const _FiltersSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).viewPadding.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Filtros',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Obx(() {
                if (controller.advancedFilterCount == 0) {
                  return const SizedBox.shrink();
                }
                return TextButton.icon(
                  onPressed: controller.clearAdvancedFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: const Text('Limpiar'),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),

          // ── Estado ──
          const _FilterSectionTitle('Estado'),
          Obx(() {
            final selected = controller.filterStatus.value;
            final activeOnly = controller.showOnlyActive.value;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppFilterChip(
                  label: 'Todas',
                  selected: selected == null && !activeOnly,
                  onTap: () {
                    if (activeOnly) controller.toggleActiveFilter();
                    controller.filterByStatus(null);
                  },
                ),
                AppFilterChip(
                  label: 'Activas',
                  selected: activeOnly,
                  onTap: () {
                    if (!activeOnly) controller.toggleActiveFilter();
                  },
                ),
                for (final status in const [
                  OrderStatus.pending,
                  OrderStatus.preparing,
                  OrderStatus.ready,
                  OrderStatus.completed,
                  OrderStatus.cancelled,
                ])
                  AppFilterChip(
                    label: status.displayName,
                    selected: selected == status && !activeOnly,
                    onTap: () {
                      if (activeOnly) controller.toggleActiveFilter();
                      controller.filterByStatus(
                        selected == status ? null : status,
                      );
                    },
                  ),
              ],
            );
          }),
          const SizedBox(height: 20),

          // ── Tipo de orden ──
          const _FilterSectionTitle('Tipo de orden'),
          Obx(() {
            final selected = controller.filterOrderType.value;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppFilterChip(
                  label: 'Todos',
                  selected: selected == null,
                  onTap: () => controller.filterByOrderType(null),
                ),
                for (final type in OrderType.values)
                  AppFilterChip(
                    label: type.displayName,
                    selected: selected == type,
                    onTap: () => controller.filterByOrderType(
                      selected == type ? null : type,
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(height: 20),

          // ── Estado de pago ──
          const _FilterSectionTitle('Estado de pago'),
          Obx(() {
            final selected = controller.filterPaymentStatus.value;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppFilterChip(
                  label: 'Todos',
                  selected: selected == null,
                  onTap: () => controller.filterByPaymentStatus(null),
                ),
                for (final ps in PaymentStatus.values)
                  AppFilterChip(
                    label: ps.displayName,
                    selected: selected == ps,
                    accentColor: paymentStatusColor(ps),
                    onTap: () => controller.filterByPaymentStatus(
                      selected == ps ? null : ps,
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Listo',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSectionTitle extends StatelessWidget {
  final String title;
  const _FilterSectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────── List ───────────────────────────────

class _OrdersList extends StatelessWidget {
  final OrdersController controller;
  const _OrdersList({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && !controller.hasOrders) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.errorMessage.value.isNotEmpty &&
          !controller.hasOrders) {
        return _ErrorState(
          message: controller.errorMessage.value,
          onRetry: controller.refreshOrders,
        );
      }

      if (!controller.hasOrders) {
        // Distinguimos "no hay NADA" (primer uso) de "no hay nada para
        // este filtro/período". Con el default en "Hoy", un negocio que
        // sí tiene historial vería el empty de primer uso si no vendió
        // hoy — confuso. Si hay algún filtro de período/estado activo,
        // mostramos el empty de filtro con acceso rápido a "Ver todas".
        if (controller.datePeriod.value != DatePeriod.all ||
            controller.filterStatus.value != null) {
          return _NoOrdersForFilter(controller: controller);
        }
        return const _EmptyState();
      }

      final visible = controller.filteredOrders;
      if (visible.isEmpty) {
        // Hay órdenes cargadas pero un filtro CLIENT-SIDE las ocultó todas.
        // Búsqueda → estado de "sin resultados"; cualquier otro filtro
        // (estado de pago) → empty de filtro con acceso a "Ver todas".
        if (controller.searchQuery.value.isNotEmpty) {
          return _NoSearchResults(
            query: controller.searchQuery.value,
            onClear: () => controller.setSearchQuery(''),
          );
        }
        return _NoOrdersForFilter(controller: controller);
      }

      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: controller.refreshOrders,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: visible.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = visible[index];
            return OrderCard(
              order: order,
              onTap: () => NavigationService.toOrderDetail(order.id),
              // Para órdenes sueltas listas para cobrar, navegamos al
              // detalle y pedimos que se abra el dialog de pago auto —
              // así no hay que tocar dos veces.
              onCharge: order.belongsToTabSession
                  ? null
                  : () => Get.toNamed(
                        '/orders/${order.id}',
                        arguments: {'auto_open_pay': true},
                      ),
              // Para órdenes que viven en una cuenta abierta, navegamos
              // a la pantalla de la cuenta (donde está el botón "Cobrar
              // cuenta" — el cobro es consolidado, no por orden).
              onOpenTabSession: order.belongsToTabSession
                  ? () => Get.toNamed(
                        '/tab-sessions/${order.tabSessionId}',
                      )
                  : null,
            );
          },
        ),
      );
    });
  }
}

// ─────────────────────────── States ───────────────────────────

/// Estado vacío cuando el query filtró todas las órdenes. El operario
/// suele tipear mal — le damos un botón para volver a ver todas sin
/// tener que vaciar el campo manualmente.
class _NoSearchResults extends StatelessWidget {
  final String query;
  final VoidCallback onClear;

  const _NoSearchResults({required this.query, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.textHint.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.search_off,
                size: 32,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Nada coincide con "$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Probá con otro número, mesa o teléfono.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Limpiar búsqueda'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state cuando el período/estado filtrado no tiene órdenes (pero
/// sí puede haber en otros días). Ofrece volver a "Todas" de un toque.
class _NoOrdersForFilter extends StatelessWidget {
  final OrdersController controller;
  const _NoOrdersForFilter({required this.controller});

  @override
  Widget build(BuildContext context) {
    final periodLabel = controller.datePeriod.value.label.toLowerCase();
    // ¿Hay filtros además del período de fecha? (estado, tipo, pago, búsqueda)
    final hasOtherFilters = controller.filterStatus.value != null ||
        controller.filterOrderType.value != null ||
        controller.filterPaymentStatus.value != null;
    final isAllPeriod = controller.datePeriod.value == DatePeriod.all;

    final subtitle = hasOtherFilters
        ? 'No hay órdenes que coincidan con los filtros seleccionados.'
        : 'No se registraron órdenes en el período "$periodLabel".';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_busy_outlined,
              size: 28,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sin órdenes para este filtro',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              if (!isAllPeriod)
                FilledButton.icon(
                  onPressed: () => controller.setDatePeriod(DatePeriod.all),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text('Ver todas'),
                ),
              if (hasOtherFilters)
                OutlinedButton.icon(
                  onPressed: controller.clearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                  label: const Text('Limpiar filtros'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 240;
        final iconSize = compact ? 56.0 : 96.0;
        final iconInner = compact ? 28.0 : 44.0;
        final gap1 = compact ? 10.0 : 20.0;
        final gap2 = compact ? 4.0 : 6.0;
        final gap3 = compact ? 10.0 : 20.0;
        final titleSize = compact ? 15.0 : 18.0;
        final subtitleSize = compact ? 12.0 : 14.0;

        return Center(
          child: Padding(
            padding: EdgeInsets.all(compact ? 16 : 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    size: iconInner,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: gap1),
                Text(
                  'Aún no hay órdenes',
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: gap2),
                Text(
                  'Cuando crees una orden aparecerá acá.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: subtitleSize,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: gap3),
                FilledButton.icon(
                  onPressed: () => NavigationService.toCreateOrder(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 16 : 24,
                      vertical: compact ? 8 : 14,
                    ),
                    minimumSize: const Size(0, 32),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    'Crear primera orden',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: subtitleSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 36,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No pudimos cargar las órdenes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
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
