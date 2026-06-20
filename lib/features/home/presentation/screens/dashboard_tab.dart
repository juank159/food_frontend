import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/routes/navigation_service.dart';
import '../../../../core/widgets/app_gradient_header.dart';
import '../../../../core/utils/safe_get.dart';
import '../../../../core/utils/ui_access.dart';
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
          child: Obx(() {
            // Decidimos qué muestra el dashboard según el rol del
            // usuario. Cada rol ve SOLO las acciones que le corresponden
            // según la lógica del negocio:
            //   - mesero: vender, cuentas, mesas, su turno, QR.
            //   - cajero: igual + caja (es quien maneja efectivo).
            //   - admin/manager: TODO + gestión.
            // El backend valida con RolesGuard (HTTP 403), pero acá
            // filtramos para no MOSTRARLE acciones que no puede usar.
            final user = authController.currentUserRx;
            final access = UiAccess.from(user);
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _buildHeader(authController,
                    isAdminOrManager: access.isAdminOrManager),
                const SizedBox(height: 18),
                _buildPrimaryActions(),
                const SizedBox(height: 22),
                _buildSectionTitle('Más acciones'),
                const SizedBox(height: 8),
                _buildSecondaryActions(access),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ─────────────────────────── Header ───────────────────────────

  Widget _buildHeader(
    AuthController authController, {
    required bool isAdminOrManager,
  }) {
    final user = authController.currentUser;
    final initials = user != null
        ? '${user.firstName[0]}${user.lastName[0]}'.toUpperCase()
        : 'U';
    final name = user?.firstName ?? 'Usuario';
    final greeting = _greetingForHour(DateTime.now().hour);

    // Admin/Manager ven KPIs financieros (ventas del día, delta vs. ayer).
    // Waiter/Cashier ven KPIs operativos (órdenes activas, mesas) — no
    // tiene sentido mostrarle "Ventas hoy" a un mesero, le distrae del
    // trabajo y puede ser información sensible que no le corresponde.
    final hero = isAdminOrManager
        ? Obx(() => AppKpiHero(
              icon: Icons.trending_up,
              label: 'Ventas del día',
              value: controller.isLoadingStats
                  ? '—'
                  : CurrencyFormatter.format(controller.totalSalesToday),
              hint: controller.isLoadingStats
                  ? 'Cargando…'
                  : controller.salesDeltaLabel,
            ))
        : Obx(() => AppKpiHero(
              icon: Icons.local_dining,
              label: 'Órdenes activas ahora',
              value: controller.isLoadingStats
                  ? '—'
                  : controller.activeOrders.toString(),
              hint: 'Listo para atender',
            ));

    return AppGradientHeader(
      title: '$greeting, $name',
      subtitle: isAdminOrManager
          ? 'Acá está el resumen de tu negocio'
          : '¿Quién va primero?',
      trailing: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.4), width: 2),
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
      hero: hero,
      // Para waiter/cashier el hero ya muestra "Órdenes activas" — sumar
      // chips repite info y satura visualmente. Los chips son útiles para
      // admin/manager que necesitan ver varios KPIs de un vistazo.
      chips: isAdminOrManager
          ? [
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
              // Ganancia neta del mes — el KPI que responde "¿estoy ganando
              // o perdiendo?" de un vistazo. Tap → estado de resultados.
              Obx(() => AppKpiChip(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Ganancia mes',
                    value: controller.isLoadingStats || !controller.hasProfitData
                        ? '—'
                        : CurrencyFormatter.formatCompact(
                            controller.netProfitMonth),
                    onTap: () => Get.toNamed(AppRoutes.profit),
                  )),
            ]
          : null,
    );
  }

  // ─────────────────────── Quick actions ───────────────────────

  /// Las 2 acciones que se usan en cada turno: Venta express y Cuentas
  /// abiertas. Diseñadas para ser tocables sin mirar — área enorme,
  /// gradiente fuerte, label corto, accesibles con el pulgar.
  Widget _buildPrimaryActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // En tablet ancho ponemos los 2 tiles bien gordos lado a lado.
          // El alto se calcula proporcional al ancho para que no se
          // estiren feo en pantallas grandes.
          final tileWidth = (constraints.maxWidth - 12) / 2;
          final tileHeight = tileWidth.clamp(120.0, 160.0);
          return Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: tileHeight,
                  child: _PrimaryActionTile(
                    icon: FontAwesomeIcons.bolt,
                    title: 'Vender',
                    subtitle: 'Mostrador, mesa, llevar…',
                    accent: AppColors.accent,
                    // Abre la pantalla unificada con modo Mostrador
                    // por defecto. El operario cambia el destino
                    // con un toque en el pill superior — sin navegar
                    // a otra pantalla.
                    onTap: () => Get.toNamed(AppRoutes.sell),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: tileHeight,
                  child: _PrimaryActionTile(
                    icon: FontAwesomeIcons.receipt,
                    title: 'Cuentas\nabiertas',
                    subtitle: 'Mesas y tickets vivos',
                    accent: AppColors.success,
                    onTap: () => Get.toNamed(AppRoutes.tabSessions),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Acciones secundarias — todo lo demás, filtrado por rol. Mesero y
  /// cashier solo ven lo que necesitan para el turno; admin/manager ven
  /// herramientas de gestión también.
  Widget _buildSecondaryActions(UiAccess access) {
    final tiles = <Widget>[
      // Estado de mesas: lo ve mesero, cajero y gerencia. El mesero
      // necesita saber qué mesa está libre/ocupada; el cocinero y
      // repartidor no.
      if (access.canSeeTables)
        _QuickActionTile(
          icon: FontAwesomeIcons.tableCells,
          title: 'Estado de mesas',
          subtitle: 'Ver ocupación y servicio en vivo',
          accent: AppColors.info,
          onTap: controller.goToTables,
        ),
      // Caja: la abre/cierra el cajero (responsable del efectivo) y
      // admin/manager para supervisión. El mesero NO — su rol no
      // incluye permisos sobre cash sessions y el backend devuelve
      // 403 si intenta entrar.
      if (access.canSeeCashRegister)
        _QuickActionTile(
          icon: FontAwesomeIcons.cashRegister,
          title: 'Caja',
          subtitle: 'Apertura, cierre y conciliación',
          accent: AppColors.warning,
          onTap: () => Get.toNamed(AppRoutes.cashRegister),
        ),
      // Mi turno: cualquier empleado puede fichar entrada/salida.
      _QuickActionTile(
        icon: FontAwesomeIcons.clock,
        title: 'Mi turno',
        subtitle: 'Marcar entrada/salida',
        accent: AppColors.primary,
        onTap: () => Get.toNamed(AppRoutes.shiftClock),
      ),
      // Pedidos por QR: el mesero los aprueba antes de que entren a
      // cocina. Cajero/admin/manager también lo ven. Cocina/delivery no.
      if (access.canSeePendingReview) _PendingReviewActionTile(),
      // Gestión (catálogo, QRs, menú del día, reportes) → solo
      // admin/manager.
      if (access.isAdminOrManager) ...[
        _QuickActionTile(
          icon: FontAwesomeIcons.bowlFood,
          title: 'Productos',
          subtitle: 'Catálogo, categorías y modificadores',
          accent: AppColors.secondary,
          onTap: controller.goToProducts,
        ),
        _QuickActionTile(
          icon: FontAwesomeIcons.qrcode,
          title: 'Códigos QR',
          subtitle: 'Crear e imprimir QRs para mesas y zonas',
          accent: Colors.indigo,
          onTap: () => Get.toNamed(AppRoutes.qrTokens),
        ),
        _QuickActionTile(
          icon: FontAwesomeIcons.calendarCheck,
          title: 'Menú del día',
          subtitle: 'Programar qué ven los clientes en self-order',
          accent: AppColors.accent,
          onTap: () => Get.toNamed(AppRoutes.menuSchedules),
        ),
        _QuickActionTile(
          icon: FontAwesomeIcons.chartLine,
          title: 'Reportes',
          subtitle: 'Ventas, productos top, márgenes',
          accent: const Color(0xFF8E44AD),
          onTap: () => NavigationService.toReports(),
        ),
      ],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            tiles[i],
            if (i < tiles.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

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

  // ─────────────────────────── Helpers ───────────────────────────

  static String _greetingForHour(int hour) {
    if (hour < 12) return 'Buen día';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
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

/// Tile cuadrado prominente para las 2 acciones que se usan en cada turno
/// (Venta express, Cuentas). Diseño "thumb-friendly": icono grande
/// arriba, label corto debajo, target táctil > 80x80px.
class _PrimaryActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _PrimaryActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.30),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

/// Tile especial para "Pedidos por QR" con badge reactivo al count
/// del watcher global. Si hay pedidos, se ve con borde naranja
/// vibrante + pill con el número. Si no, se ve normal.
class _PendingReviewActionTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // El watcher se registra como permanent en main.dart, pero el
    // SafeGet evita crash si por algún motivo no estuviera (ej.
    // testing aislado o hot reload edge case). Si no está, count=0.
    final watcher = SafeGet.find<PendingReviewWatcher>();
    return Obx(() {
      final count = watcher?.count.value ?? 0;
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
