// lib/features/home/presentation/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/routes/navigation_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../orders/presentation/pages/orders_page.dart';
import '../../../products/presentation/pages/products_page.dart';
import '../controllers/home_controller.dart';
import 'dashboard_tab.dart';
import '../../../../core/utils/app_dialog.dart';

/// Home Screen - Pantalla principal con navegación inferior
class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Scaffold(
        body: IndexedStack(
          index: controller.currentIndex,
          children: [
            // Tab 0: Dashboard
            const DashboardTab(),

            // Tab 1: Órdenes — montamos la OrdersPage real (sin pantalla
            // intermedia con botón "Ver detalles", que era confusa). El
            // OrdersController vive en HomeBinding para que esto funcione.
            const OrdersPage(),

            // Tab 2: Productos - Vista real del listado
            const ProductsPage(),

            // Tab 3: Más opciones
            _buildMoreTab(),
          ],
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      );
    });
  }

  Widget _buildBottomNavigationBar() {
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
        currentIndex: controller.currentIndex,
        onTap: controller.changeIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.house, size: 20),
            activeIcon: Icon(FontAwesomeIcons.house, size: 22),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.fileInvoice, size: 20),
            activeIcon: Icon(FontAwesomeIcons.fileInvoice, size: 22),
            label: 'Órdenes',
          ),
          BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.bowlFood, size: 20),
            activeIcon: Icon(FontAwesomeIcons.bowlFood, size: 22),
            label: 'Productos',
          ),
          BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.ellipsis, size: 20),
            activeIcon: Icon(FontAwesomeIcons.ellipsis, size: 22),
            label: 'Más',
          ),
        ],
      ),
    );
  }

  Widget _buildMoreTab() {
    final authController = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Más Opciones'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      // Filtramos el menú según el rol del usuario actual. Los items
      // sensibles (empleados, reportes, suscripción, configuración del
      // negocio) solo aparecen para admin/manager. El backend además
      // bloquea con `RolesGuard` — esto es UX, no seguridad.
      body: Obx(() {
        final user = authController.currentUserRx;
        final isAdmin = user?.isAdmin == true;
        final isAdminOrManager = user?.isAdminOrManager == true;

        final managementItems = <Widget>[
          _buildMenuItem(
            icon: FontAwesomeIcons.users,
            title: 'Clientes',
            subtitle: 'Gestiona tus clientes',
            onTap: () => NavigationService.toCustomers(),
          ),
          if (isAdminOrManager)
            _buildMenuItem(
              icon: FontAwesomeIcons.userTie,
              title: 'Empleados',
              subtitle: 'Administra tu equipo',
              onTap: () => NavigationService.toEmployees(),
            ),
          if (isAdminOrManager)
            _buildMenuItem(
              icon: FontAwesomeIcons.chair,
              title: 'Mesas',
              subtitle: 'Configura tus mesas',
              onTap: () => NavigationService.toTables(),
            ),
          if (isAdminOrManager)
            _buildMenuItem(
              icon: FontAwesomeIcons.boxesStacked,
              title: 'Inventario',
              subtitle: 'Control de stock',
              onTap: () => NavigationService.toInventory(),
            ),
          _buildMenuItem(
            icon: FontAwesomeIcons.calendarDays,
            title: 'Reservaciones',
            subtitle: 'Reservas y disponibilidad',
            onTap: () => NavigationService.toReservations(),
          ),
        ];

        final reportItems = <Widget>[
          if (isAdminOrManager)
            _buildMenuItem(
              icon: FontAwesomeIcons.chartLine,
              title: 'Reportes',
              subtitle: 'Análisis de ventas',
              onTap: () => NavigationService.toReports(),
            ),
          if (isAdminOrManager)
            _buildMenuItem(
              icon: FontAwesomeIcons.dollarSign,
              title: 'Ventas',
              subtitle: 'Historial de ventas',
              onTap: () => NavigationService.toSalesReport(),
            ),
        ];

        final settingsItems = <Widget>[
          if (isAdmin)
            _buildMenuItem(
              icon: FontAwesomeIcons.crown,
              title: 'Mi Suscripción',
              subtitle: 'Plan actual y límites',
              onTap: () => NavigationService.toSubscription(),
            ),
          _buildMenuItem(
            icon: FontAwesomeIcons.user,
            title: 'Mi Perfil',
            subtitle: 'Información personal',
            onTap: () => NavigationService.toProfile(),
          ),
          if (isAdmin)
            _buildMenuItem(
              icon: FontAwesomeIcons.building,
              title: 'Negocio',
              subtitle: 'Configuración del restaurante',
              onTap: () => NavigationService.toBusinessSettings(),
            ),
          if (isAdminOrManager)
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
            if (settingsItems.isNotEmpty) ...[
              _buildMenuSection(
                title: 'Configuración',
                items: settingsItems,
              ),
              const SizedBox(height: 24),
            ],
            _buildLogoutButton(authController),
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

  Widget _buildLogoutButton(AuthController authController) {
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
                  onPressed: () => Get.back(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Get.back();
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
