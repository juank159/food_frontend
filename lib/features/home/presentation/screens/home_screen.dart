// lib/features/home/presentation/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:printing/printing.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/routes/navigation_service.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../../../../core/utils/menu_pdf_builder.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/usecases/get_active_categories_usecase.dart';
import '../../../orders/presentation/pages/orders_page.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/domain/usecases/get_products_usecase.dart';
import '../../../products/presentation/pages/products_page.dart';
import '../../../tables/presentation/pages/floor_plans_list_page.dart';
import '../../../../core/routes/app_routes.dart';
import '../controllers/home_controller.dart';
import 'dashboard_tab.dart';
import 'delivery_dashboard.dart';
import 'kitchen_dashboard.dart';
import '../../../../core/utils/app_dialog.dart';
import '../../../../core/utils/ui_access.dart';
import '../../../../core/widgets/widgets.dart';

/// Home Screen - Pantalla principal con navegación inferior.
///
/// El bottomNavigationBar y los tabs **se filtran por rol**:
///   - admin/manager: Inicio, Órdenes, Productos, Más  (gestión completa).
///   - waiter/cashier/otros: Inicio, Órdenes, Mesas, Más (sin Productos —
///     gestión de catálogo no aplica a sus turnos).
///
/// Esto evita que un mesero vea una pestaña "Productos" que no le sirve
/// para tomar pedidos y libera el slot para algo más útil (Mesas).
class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    return Obx(() {
      final user = authController.currentUserRx;
      final roleCode = user?.roleCode;
      final tabs = _buildTabsForRole(context: context, roleCode: roleCode);
      // Si por alguna razón el index actual quedó fuera de rango
      // (cambio de rol después de login), lo corregimos al primero.
      final safeIndex =
          controller.currentIndex.clamp(0, tabs.length - 1);
      return Scaffold(
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: IndexedStack(
                index: safeIndex,
                children: tabs.map((t) => t.body).toList(),
              ),
            ),
          ],
        ),
        bottomNavigationBar:
            _buildBottomNavigationBar(safeIndex: safeIndex, tabs: tabs),
      );
    });
  }

  /// Cada rol ve un set de tabs distinto. La idea es que ningún
  /// operario pierda tiempo navegando por tabs que no le sirven.
  ///
  ///   - `kitchen` / `bartender`: pantalla KDS full-screen (tickets
  ///     en preparación). Solo Inicio + Más (mínimo).
  ///   - `delivery`: lista de repartos con dirección/teléfono/mapa.
  ///     Solo Inicio + Más.
  ///   - `waiter` / `cashier`: Inicio + Órdenes + Mesas + Más.
  ///   - `admin` / `manager` (o sin rol detectado): tab completo con
  ///     gestión (Inicio + Órdenes + Productos + Más).
  List<_HomeTab> _buildTabsForRole({
    required BuildContext context,
    required String? roleCode,
  }) {
    final isKitchen = roleCode == 'kitchen' || roleCode == 'bartender';
    final isDelivery = roleCode == 'delivery';
    final isAdminOrManager =
        roleCode == 'admin' || roleCode == 'manager' || roleCode == null;

    // Cocina y barra: solo KDS + Más. La pantalla principal es el KDS,
    // que ya es full-featured (tickets, marcar listo, etc.).
    if (isKitchen) {
      return [
        const _HomeTab(
          icon: FontAwesomeIcons.kitchenSet,
          label: 'Cocina',
          body: KitchenDashboard(),
        ),
        _HomeTab(
          icon: FontAwesomeIcons.ellipsis,
          label: 'Más',
          body: _buildMoreTab(context),
        ),
      ];
    }

    // Repartidor: solo lista de repartos + Más.
    if (isDelivery) {
      return [
        const _HomeTab(
          icon: FontAwesomeIcons.motorcycle,
          label: 'Repartos',
          body: DeliveryDashboard(),
        ),
        _HomeTab(
          icon: FontAwesomeIcons.ellipsis,
          label: 'Más',
          body: _buildMoreTab(context),
        ),
      ];
    }

    // Resto (admin/manager/waiter/cashier).
    return [
      const _HomeTab(
        icon: FontAwesomeIcons.house,
        label: 'Inicio',
        body: DashboardTab(),
      ),
      const _HomeTab(
        icon: FontAwesomeIcons.fileInvoice,
        label: 'Órdenes',
        body: OrdersPage(),
      ),
      if (isAdminOrManager)
        const _HomeTab(
          icon: FontAwesomeIcons.bowlFood,
          label: 'Productos',
          body: ProductsPage(),
        )
      else
        const _HomeTab(
          icon: FontAwesomeIcons.chair,
          label: 'Mesas',
          // Muestra la lista de planos. Al tap entra a `TableStatusPage`
          // del plano. La binding del controller se registra en el
          // HomeBinding (lazy) la primera vez que se renderice.
          body: FloorPlansListPage(),
        ),
      _HomeTab(
        icon: FontAwesomeIcons.ellipsis,
        label: 'Más',
        body: _buildMoreTab(context),
      ),
    ];
  }

  Widget _buildBottomNavigationBar({
    required int safeIndex,
    required List<_HomeTab> tabs,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: controller.changeIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 0,
        items: [
          for (final t in tabs)
            BottomNavigationBarItem(
              icon: Icon(t.icon, size: 20),
              activeIcon: Icon(t.icon, size: 22),
              label: t.label,
            ),
        ],
      ),
    );
  }

  Widget _buildMoreTab(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Más Opciones'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      // El menú "Más" filtra cada item con `UiAccess` — la misma matriz
      // de permisos que usa el dashboard. Antes, ítems como "Clientes"
      // y "Reservaciones" se mostraban a TODOS porque estaban fuera del
      // bloque condicional; resultado: el cocinero veía clientes y
      // reservas que no le sirven. Ahora cada item declara su acceso
      // explícito y el rol que no aplique simplemente no lo ve.
      body: Obx(() {
        final user = authController.currentUserRx;
        final access = UiAccess.from(user);

        final managementItems = <Widget>[
          if (access.canSeeProducts) const _CartaPdfTile(),
          if (access.canSeeCustomers)
            _buildMenuItem(
              icon: FontAwesomeIcons.users,
              title: 'Clientes',
              subtitle: 'Gestiona tus clientes',
              onTap: () => NavigationService.toCustomers(),
            ),
          if (access.canSeeEmployees)
            _buildMenuItem(
              icon: FontAwesomeIcons.userTie,
              title: 'Empleados',
              subtitle: 'Administra tu equipo',
              onTap: () => NavigationService.toEmployees(),
            ),
          if (access.canSeeTablesAdmin)
            _buildMenuItem(
              icon: FontAwesomeIcons.chair,
              title: 'Mesas',
              subtitle: 'Configura tus mesas',
              onTap: () => NavigationService.toTables(),
            ),
          if (access.canSeeInventory)
            _buildMenuItem(
              icon: FontAwesomeIcons.boxesStacked,
              title: 'Inventario',
              subtitle: 'Control de stock',
              onTap: () => NavigationService.toInventory(),
            ),
          if (access.canSeeChecklist)
            _buildMenuItem(
              icon: FontAwesomeIcons.listCheck,
              title: 'Lista de compras',
              subtitle: 'Lo que hace falta comprar',
              onTap: () => Get.toNamed(AppRoutes.checklist),
            ),
          if (access.canSeeReservations)
            _buildMenuItem(
              icon: FontAwesomeIcons.calendarDays,
              title: 'Reservaciones',
              subtitle: 'Reservas y disponibilidad',
              onTap: () => NavigationService.toReservations(),
            ),
        ];

        final reportItems = <Widget>[
          if (access.canSeeReports)
            _buildMenuItem(
              icon: FontAwesomeIcons.chartLine,
              title: 'Reportes',
              subtitle: 'Análisis de ventas',
              onTap: () => NavigationService.toReports(),
            ),
          if (access.canSeeSalesReport)
            _buildMenuItem(
              icon: FontAwesomeIcons.dollarSign,
              title: 'Ventas',
              subtitle: 'Historial de ventas',
              onTap: () => NavigationService.toSalesReport(),
            ),
        ];

        final financeItems = <Widget>[
          if (access.canSeeFinance)
            _buildMenuItem(
              icon: FontAwesomeIcons.chartPie,
              title: 'Ganancias',
              subtitle: 'Ingresos − costos − gastos − nómina',
              onTap: () => Get.toNamed(AppRoutes.profit),
            ),
          if (access.canSeeFinance)
            _buildMenuItem(
              icon: FontAwesomeIcons.receipt,
              title: 'Gastos',
              subtitle: 'Egresos del negocio',
              onTap: () => Get.toNamed(AppRoutes.expenses),
            ),
          if (access.canSeeFinance)
            _buildMenuItem(
              icon: FontAwesomeIcons.sackDollar,
              title: 'Nómina',
              subtitle: 'Pagos al personal por período',
              onTap: () => Get.toNamed(AppRoutes.payroll),
            ),
        ];

        final settingsItems = <Widget>[
          if (access.canSeeSubscription)
            _buildMenuItem(
              icon: FontAwesomeIcons.crown,
              title: 'Mi Suscripción',
              subtitle: 'Plan actual y límites',
              onTap: () => NavigationService.toSubscription(),
            ),
          if (access.canSeeProfile)
            _buildMenuItem(
              icon: FontAwesomeIcons.user,
              title: 'Mi Perfil',
              subtitle: 'Información personal',
              onTap: () => NavigationService.toProfile(),
            ),
          if (access.canSeeBusinessSettings)
            _buildMenuItem(
              icon: FontAwesomeIcons.building,
              title: 'Negocio',
              subtitle: 'Configuración del restaurante',
              onTap: () => NavigationService.toBusinessSettings(),
            ),
          if (access.canSeeGeneralSettings)
            _buildMenuItem(
              icon: FontAwesomeIcons.gear,
              title: 'Configuración',
              subtitle: 'Ajustes generales',
              onTap: () => NavigationService.toSettings(),
            ),
        ];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (managementItems.isNotEmpty) ...[
              _buildMenuSection(title: 'Gestión', items: managementItems),
              const SizedBox(height: 24),
            ],
            if (reportItems.isNotEmpty) ...[
              _buildMenuSection(
                title: 'Reportes y Análisis',
                items: reportItems,
              ),
              const SizedBox(height: 24),
            ],
            if (financeItems.isNotEmpty) ...[
              _buildMenuSection(
                title: 'Finanzas',
                items: financeItems,
              ),
              const SizedBox(height: 24),
            ],
            if (settingsItems.isNotEmpty) ...[
              _buildMenuSection(
                title: 'Configuración',
                items: settingsItems,
              ),
              const SizedBox(height: 24),
            ],
            _buildLogoutButton(context, authController),
            const SizedBox(height: 24),
          ],
        );
      }),
    );
  }

  Widget _buildMenuSection({
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthController authController) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          AppDialog.show(
            AlertDialog(
              title: const Text('Cerrar Sesión'),
              content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    authController.logout();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                  child: const Text('Cerrar Sesión'),
                ),
              ],
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  FontAwesomeIcons.arrowRightFromBracket,
                  color: AppColors.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Cerrar Sesión',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.error),
            ],
          ),
        ),
      ),
    );
  }
}

/// Descriptor de una pestaña del home — combina el icono visible en el
/// bottom nav, el label corto y el body que se renderiza en el
/// IndexedStack. Permite armar la lista de tabs declarativamente sin
/// duplicar lógica de "qué muestra cada pestaña".
class _HomeTab {
  final IconData icon;
  final String label;
  final Widget body;

  const _HomeTab({
    required this.icon,
    required this.label,
    required this.body,
  });
}

/// Ítem del menú "Más" para descargar/compartir la carta en PDF.
/// Tiene estado propio para mostrar un spinner mientras genera el archivo.
class _CartaPdfTile extends StatefulWidget {
  const _CartaPdfTile();

  @override
  State<_CartaPdfTile> createState() => _CartaPdfTileState();
}

class _CartaPdfTileState extends State<_CartaPdfTile> {
  bool _loading = false;

  Future<void> _download() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      // Lanzar los tres requests en paralelo (se inician antes del primer await)
      final tenantFuture     = sl<dio_pkg.Dio>().get('/tenants/me');
      final productsFuture   = sl<GetProductsUseCase>().call(isAvailable: true, limit: 500);
      final categoriesFuture = sl<GetActiveCategoriesUseCase>().call();

      final tenantResp       = await tenantFuture;
      final productsResult   = await productsFuture;
      final categoriesResult = await categoriesFuture;

      // Datos del negocio
      final tenant  = ApiResponseUtils.object(tenantResp);
      final settings = (tenant['settings'] as Map?)?.cast<String, dynamic>() ?? {};
      final contact  = (settings['contact'] as Map?)?.cast<String, dynamic>() ?? {};
      final receipt  = (settings['receipt'] as Map?)?.cast<String, dynamic>() ?? {};

      final restaurantName = ((tenant['business_name'] as String?)?.trim().isNotEmpty == true
              ? tenant['business_name'] as String
              : null) ??
          'Mi Restaurante';
      final address = (contact['address'] as String?)?.trim();
      final phone   = (contact['phone'] as String?)?.trim();
      final logoUrl = (receipt['logo_url'] as String?)?.trim();

      // Productos y categorías — tipos preservados porque no hay List<dynamic> intermedia
      final products   = productsResult.fold<List<Product>>(
        (_) => <Product>[], (list) => list,
      );
      final categories = categoriesResult.fold<List<Category>>(
        (_) => <Category>[], (list) => list,
      );

      if (products.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay productos para generar la carta.')),
          );
        }
        return;
      }

      final bytes = await MenuPdfBuilder.build(
        products: products,
        categories: categories,
        restaurantName: restaurantName,
        restaurantAddress: address?.isNotEmpty == true ? address : null,
        restaurantPhone: phone?.isNotEmpty == true ? phone : null,
        logoUrl: logoUrl?.isNotEmpty == true ? logoUrl : null,
      );

      await Printing.sharePdf(bytes: bytes, filename: 'carta.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo generar el PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _loading ? null : _download,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.picture_as_pdf_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Descargar carta PDF',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Carta completa con imágenes y precios para compartir',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
