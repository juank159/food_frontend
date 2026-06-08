import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/routes/navigation_service.dart';
import '../../../../core/widgets/app_gradient_header.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../orders/presentation/controllers/pending_review_watcher.dart';
import '../controllers/home_controller.dart';

/// Dashboard — pantalla de inicio.
///
/// Estructura: header con gradient (saludo + avatar + KPI hero "ventas
/// del día") → grid de stats con borde de color → sección de acciones
/// rápidas con jerarquía visual.
///
/// Mismo lenguaje visual que `OrdersPage`/`ProductsPage`/`FloorPlansListPage`.
class DashboardTab extends GetView<HomeController> {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: controller.refreshStats,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _buildHeader(authController),
              const SizedBox(height: 16),
              _buildStatsGrid(context),
              const SizedBox(height: 24),
              _buildSectionTitle('Acciones rápidas'),
              const SizedBox(height: 8),
              _buildQuickActions(),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── Header ───────────────────────────

  Widget _buildHeader(AuthController authController) {
    return Obx(() {
      final user = authController.currentUser;
      final initials = user != null
          ? '${user.firstName[0]}${user.lastName[0]}'.toUpperCase()
          : 'U';
      final name = user?.firstName ?? 'Usuario';
      final greeting = _greetingForHour(DateTime.now().hour);
      return AppGradientHeader(
        title: '$greeting, $name',
        subtitle: 'Acá está el resumen de tu negocio',
        trailing: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
        hero: Obx(() => AppKpiHero(
              icon: Icons.trending_up,
              label: 'Ventas del día',
              value: controller.isLoadingStats
                  ? '—'
                  : CurrencyFormatter.format(controller.totalSalesToday),
              // `salesDeltaLabel` calcula el delta real vs. ayer
              // consultando otro endpoint con rango del día anterior.
              // Si no hay ventas comparables muestra "Sin datos de ayer"
              // o "Primera venta del día" — nunca un número falso.
              hint: controller.isLoadingStats
                  ? 'Cargando…'
                  : controller.salesDeltaLabel,
            )),
        chips: [
          Obx(() => AppKpiChip(
                icon: Icons.receipt_long,
                label: 'Órdenes',
                value: controller.isLoadingStats
                    ? '—'
                    : controller.activeOrders.toString(),
                onTap: () => NavigationService.toOrders(),
              )),
          Obx(() => AppKpiChip(
                icon: Icons.chair,
                label: 'Mesas',
                value: controller.isLoadingStats
                    ? '—'
                    : controller.tablesOccupancyLabel,
                onTap: () => NavigationService.toTables(),
              )),
          Obx(() => AppKpiChip(
                icon: Icons.people_alt_outlined,
                label: 'Clientes',
                value: controller.isLoadingStats
                    ? '—'
                    : controller.totalCustomers.toString(),
                onTap: () => NavigationService.toCustomers(),
              )),
        ],
      );
    });
  }

  // ─────────────────────────── Stats grid ───────────────────────────

  Widget _buildStatsGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Obx(() {
        if (controller.isLoadingStats) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        // En desktop/tablet damos más columnas. En mobile (lo más común)
        // mostramos 2x2 para que no se sienta apretado.
        final width = MediaQuery.of(context).size.width;
        final columns = width >= 900 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: columns == 4 ? 1.5 : 1.4,
          children: [
            _DashboardStatCard(
              icon: Icons.attach_money,
              label: 'Ventas hoy',
              value: CurrencyFormatter.format(controller.totalSalesToday),
              accent: AppColors.success,
              hint: controller.salesDeltaLabel,
              onTap: () => NavigationService.toSalesReport(),
            ),
            _DashboardStatCard(
              icon: Icons.pending_actions,
              label: 'Órdenes activas',
              value: controller.activeOrders.toString(),
              accent: AppColors.primary,
              onTap: () => NavigationService.toOrders(),
            ),
            _DashboardStatCard(
              icon: Icons.chair,
              label: 'Mesas ocupadas',
              value: controller.tablesOccupancyLabel,
              accent: AppColors.warning,
              onTap: () => NavigationService.toTables(),
            ),
            _DashboardStatCard(
              // El endpoint `/customers/statistics` devuelve el TOTAL
              // acumulado de clientes en la BD, no los de hoy. Antes el
              // label decía "Clientes hoy" — mentira. Corregido.
              icon: Icons.people_alt_outlined,
              label: 'Clientes totales',
              value: controller.totalCustomers.toString(),
              accent: AppColors.info,
              onTap: () => NavigationService.toCustomers(),
            ),
          ],
        );
      }),
    );
  }

  // ─────────────────────── Quick actions ───────────────────────

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _QuickActionTile(
            icon: FontAwesomeIcons.plus,
            title: 'Nueva orden',
            subtitle: 'Tomar un pedido al instante',
            accent: AppColors.primary,
            onTap: controller.createNewOrder,
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: FontAwesomeIcons.bowlFood,
            title: 'Gestionar productos',
            subtitle: 'Catálogo, categorías y modificadores',
            accent: AppColors.secondary,
            onTap: controller.goToProducts,
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: FontAwesomeIcons.tableCells,
            title: 'Estado de mesas',
            subtitle: 'Ver ocupación y servicio en vivo',
            accent: AppColors.info,
            onTap: controller.goToTables,
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: FontAwesomeIcons.receipt,
            title: 'Cuentas abiertas',
            subtitle: 'Mesas y tickets activos · saldos pendientes',
            accent: AppColors.success,
            onTap: () => Get.toNamed(AppRoutes.tabSessions),
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: FontAwesomeIcons.cashRegister,
            title: 'Caja',
            subtitle: 'Apertura, cierre y conciliación de efectivo',
            accent: AppColors.warning,
            onTap: () => Get.toNamed(AppRoutes.cashRegister),
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: FontAwesomeIcons.clock,
            title: 'Mi turno',
            subtitle: 'Marcar entrada/salida y ver historial',
            accent: AppColors.primary,
            onTap: () => Get.toNamed(AppRoutes.shiftClock),
          ),
          const SizedBox(height: 10),
          // Tile con badge animado del watcher global. El count es
          // reactivo — sube/baja sin refrescar la pantalla.
          _PendingReviewActionTile(),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: FontAwesomeIcons.qrcode,
            title: 'Códigos QR',
            subtitle: 'Crear e imprimir QRs para mesas y zonas',
            accent: Colors.indigo,
            onTap: () => Get.toNamed(AppRoutes.qrTokens),
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: FontAwesomeIcons.calendarCheck,
            title: 'Menú del día',
            subtitle: 'Programar qué productos ven los clientes en self-order',
            accent: AppColors.accent,
            onTap: () => Get.toNamed(AppRoutes.menuSchedules),
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: FontAwesomeIcons.chartLine,
            title: 'Reportes',
            subtitle: 'Ventas, productos top, márgenes',
            accent: const Color(0xFF8E44AD),
            onTap: () => NavigationService.toReports(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── Helpers ───────────────────────────

  static String _greetingForHour(int hour) {
    if (hour < 12) return 'Buen día';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }
}

/// Card de KPI del dashboard. Borde sutil del color del KPI + icono
/// dentro de un cuadrado tintado, igual que el resto del lenguaje visual.
class _DashboardStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final String? hint;
  final VoidCallback? onTap;

  const _DashboardStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.hint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accent, size: 18),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.textHint,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      hint!,
                      style: TextStyle(
                        fontSize: 11,
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tile horizontal de acción rápida. Reemplaza al `QuickActionCard`
/// anterior que tenía borde grueso de color — preferimos un avatar
/// tintado y una jerarquía con título + subtítulo descriptivo.
class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.textHint,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tile especial para "Pedidos por QR" con badge reactivo al count
/// del watcher global. Si hay pedidos, se ve con borde naranja
/// vibrante + pill con el número. Si no, se ve normal.
class _PendingReviewActionTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final watcher = Get.find<PendingReviewWatcher>();
    return Obx(() {
      final count = watcher.count.value;
      final hasPending = count > 0;
      final accent = Colors.deepOrange;

      return Material(
        color: hasPending
            ? accent.withValues(alpha: 0.08)
            : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => Get.toNamed(AppRoutes.pendingReviewOrders),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasPending
                    ? accent.withValues(alpha: 0.5)
                    : AppColors.border,
                width: hasPending ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        FontAwesomeIcons.bellConcierge,
                        size: 18,
                        color: accent,
                      ),
                    ),
                    if (hasPending)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 22,
                            minHeight: 22,
                          ),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.cardBackground,
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedidos por QR',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: hasPending
                              ? accent
                              : AppColors.textPrimary,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasPending
                            ? (count == 1
                                ? '1 pedido esperando aprobación'
                                : '$count pedidos esperando aprobación')
                            : 'Pedidos por aprobar de clientes en mesa',
                        style: TextStyle(
                          fontSize: 12,
                          color: hasPending
                              ? accent.withValues(alpha: 0.85)
                              : AppColors.textSecondary,
                          fontWeight:
                              hasPending ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: hasPending ? accent : AppColors.textHint,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
