import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/navigation_service.dart';
import '../../../../core/widgets/app_filter_chip.dart';
import '../../../../core/widgets/app_primary_action_bar.dart';
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
            _SearchBar(controller: controller),
            _StatusFilterBar(controller: controller),
            const SizedBox(height: 8),
            Expanded(child: _OrdersList(controller: controller)),
          ],
        ),
      ),
      // Cuando ya hay órdenes mostramos solo un FAB con icono (sin
      // label) para no robar espacio sobre la lista. Cuando NO hay
      // órdenes, la acción primaria se muestra como una barra ancha en
      // el bottomNavigationBar — más prominente y sin riesgo de
      // overflow del label.
      floatingActionButton: Obx(() {
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: título + búsqueda. Sin AppBar dedicado — más limpio
          // y aprovechamos el real estate vertical en mobile.
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Órdenes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Resumen de hoy',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: controller.refreshOrders,
                tooltip: 'Refrescar',
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Card principal con el total del día — el KPI más importante
          // para el dueño / cajero al primer vistazo.
          Obx(() => _SalesCard(
                amount: controller.totalSalesToday,
                completedCount: controller.orders
                    .where((o) =>
                        o.isCompleted &&
                        _isSameDay(o.createdAt, DateTime.now()))
                    .length,
              )),
          const SizedBox(height: 14),
          // Stats secundarios — chips compactos transparentes que se ven
          // sobre el gradient sin pelear con el card de arriba.
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

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _SalesCard extends StatelessWidget {
  final double amount;
  final int completedCount;
  const _SalesCard({required this.amount, required this.completedCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.trending_up,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ventas del día',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  CurrencyFormatter.format(amount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$completedCount ${completedCount == 1 ? "orden cerrada" : "órdenes cerradas"}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(height: 4),
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

// ─────────────────────────── Search bar ───────────────────────────

/// Búsqueda local sobre las órdenes ya cargadas. Filtra por número,
/// cliente, teléfono o mesa. No hace request al backend — el debounce
/// no es necesario porque trabajamos con la lista en memoria.
class _SearchBar extends StatefulWidget {
  final OrdersController controller;
  const _SearchBar({required this.controller});

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.controller.searchQuery.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _ctrl,
        onChanged: widget.controller.setSearchQuery,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Buscar # de orden, mesa, cliente, teléfono…',
          hintStyle: const TextStyle(
            fontSize: 13,
            color: AppColors.textHint,
          ),
          prefixIcon: const Icon(Icons.search, size: 20),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 38, minHeight: 38),
          suffixIcon: Obx(() {
            if (widget.controller.searchQuery.value.isEmpty) {
              return const SizedBox.shrink();
            }
            return IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                _ctrl.clear();
                widget.controller.setSearchQuery('');
              },
            );
          }),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.4),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Status filter bar ───────────────────────────

/// Segmented inline para filtrar por estado. Mucho más rápido que un dialog.
/// "Todas" / "Activas" / por estado individual. Los más usados primero.
class _StatusFilterBar extends StatelessWidget {
  final OrdersController controller;
  const _StatusFilterBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: SizedBox(
        height: 36,
        child: Obx(() {
          final selectedStatus = controller.filterStatus.value;
          final activeOnly = controller.showOnlyActive.value;
          // null = "Todas", "active" = activeOnly, o un OrderStatus puntual
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            children: [
              AppFilterChip(
                label: 'Todas',
                selected: selectedStatus == null && !activeOnly,
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
                  selected: selectedStatus == status && !activeOnly,
                  onTap: () {
                    if (activeOnly) controller.toggleActiveFilter();
                    controller.filterByStatus(
                      selectedStatus == status ? null : status,
                    );
                  },
                ),
            ],
          );
        }),
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
        return const _EmptyState();
      }

      final visible = controller.filteredOrders;
      if (visible.isEmpty && controller.searchQuery.value.isNotEmpty) {
        return _NoSearchResults(
          query: controller.searchQuery.value,
          onClear: () => controller.setSearchQuery(''),
        );
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // "Ilustración" minimal — círculo grande con icono. Suficiente
            // para que el espacio no se sienta vacío sin meter assets PNG.
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Aún no hay órdenes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Cuando crees una orden aparecerá acá. Empezá tomando el primer pedido del día.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => NavigationService.toCreateOrder(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              icon: const Icon(Icons.add),
              label: const Text(
                'Crear primera orden',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
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
