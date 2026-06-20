import 'package:get/get.dart';
import '../widgets/app_placeholder_screen.dart';
import '../../features/auth/presentation/bindings/auth_binding.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/categories/presentation/bindings/categories_binding.dart';
import '../../features/categories/presentation/bindings/category_detail_binding.dart';
import '../../features/categories/presentation/bindings/category_form_binding.dart';
import '../../features/categories/presentation/pages/categories_page.dart';
import '../../features/flavors/presentation/pages/flavors_page.dart';
import '../../features/categories/presentation/pages/category_detail_page.dart';
import '../../features/categories/presentation/pages/category_form_page.dart';
import '../../features/customers/presentation/bindings/customer_detail_binding.dart';
import '../../features/customers/presentation/bindings/customer_form_binding.dart';
import '../../features/customers/presentation/bindings/customers_binding.dart';
import '../../features/customers/presentation/pages/customer_detail_page.dart';
import '../../features/customers/presentation/pages/customer_form_page.dart';
import '../../features/customers/presentation/pages/customers_page.dart';
import '../../features/employees/presentation/bindings/employee_detail_binding.dart';
import '../../features/employees/presentation/bindings/employee_form_binding.dart';
import '../../features/employees/presentation/bindings/employees_binding.dart';
import '../../features/employees/presentation/pages/employee_detail_page.dart';
import '../../features/employees/presentation/pages/employee_form_page.dart';
import '../../features/employees/presentation/pages/employees_page.dart';
import '../../features/home/presentation/bindings/home_binding.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/orders/presentation/bindings/edit_order_binding.dart';
import '../../features/orders/presentation/bindings/order_detail_binding.dart';
import '../../features/orders/presentation/bindings/orders_binding.dart';
import '../../features/orders/presentation/bindings/sell_binding.dart';
import '../../features/orders/presentation/pages/edit_order_page.dart';
import '../../features/orders/presentation/pages/order_detail_page.dart';
import '../../features/orders/presentation/pages/sell_page.dart';
import '../../features/cash_sessions/presentation/bindings/cash_session_binding.dart';
import '../../features/cash_sessions/presentation/pages/cash_register_page.dart';
import '../../features/roles/presentation/bindings/role_binding.dart';
import '../../features/roles/presentation/pages/roles_list_page.dart';
import '../../features/shifts/presentation/bindings/shift_binding.dart';
import '../../features/shifts/presentation/pages/shift_clock_page.dart';
import '../../features/tab_sessions/presentation/bindings/open_tabs_binding.dart';
import '../../features/tab_sessions/presentation/bindings/tab_session_detail_binding.dart';
import '../../features/tab_sessions/presentation/pages/open_tabs_page.dart';
import '../../features/tab_sessions/presentation/pages/tab_session_detail_page.dart';
import '../../features/tab_sessions/presentation/pages/tab_session_pay_page.dart';
import '../../features/orders/presentation/pages/orders_page.dart';
import '../../features/orders/presentation/pages/unpaid_orders_page.dart';
import '../../features/checklist/presentation/screens/checklist_screen.dart';
import '../../features/orders/presentation/pages/pending_review_page.dart';
import '../../features/orders/presentation/bindings/pending_review_binding.dart';
import '../../features/qr_tokens/presentation/pages/qr_tokens_page.dart';
import '../../features/qr_tokens/presentation/pages/qr_preview_page.dart';
import '../../features/qr_tokens/presentation/bindings/qr_tokens_binding.dart';
import '../../features/menu_schedules/presentation/pages/menu_schedules_page.dart';
import '../../features/menu_schedules/presentation/bindings/menu_schedules_binding.dart';
import '../../features/settings/presentation/screens/business_info_screen.dart';
import '../../features/products/presentation/bindings/modifier_form_binding.dart';
import '../../features/products/presentation/bindings/modifiers_binding.dart';
import '../../features/products/presentation/bindings/product_detail_binding.dart';
import '../../features/products/presentation/bindings/product_form_binding.dart';
import '../../features/products/presentation/bindings/products_binding.dart';
import '../../features/products/presentation/pages/modifier_form_page.dart';
import '../../features/products/presentation/pages/modifiers_page.dart';
import '../../features/products/presentation/pages/product_detail_page.dart';
import '../../features/products/presentation/pages/product_form_page.dart';
import '../../features/products/presentation/pages/products_page.dart';
import '../../features/settings/presentation/screens/business_settings_screen.dart';
import '../../features/settings/presentation/screens/change_password_screen.dart';
import '../../features/settings/presentation/screens/notification_settings_screen.dart';
import '../../features/settings/presentation/screens/printer_settings_screen.dart';
import '../../features/settings/presentation/screens/profile_screen.dart';
import '../../features/settings/presentation/screens/security_settings_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/tenant_payment_accounts/presentation/bindings/tenant_payment_account_binding.dart';
import '../../features/tenant_payment_accounts/presentation/pages/payment_accounts_settings_page.dart';
import '../../features/splash/presentation/bindings/splash_binding.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/subscriptions/presentation/bindings/subscription_binding.dart';
import '../../features/subscriptions/presentation/pages/subscription_page.dart';
import '../../features/reports/presentation/bindings/customer_report_binding.dart';
import '../../features/reports/presentation/bindings/employee_report_binding.dart';
import '../../features/reports/presentation/bindings/inventory_report_binding.dart';
import '../../features/reports/presentation/bindings/reports_binding.dart';
import '../../features/reports/presentation/bindings/sales_report_binding.dart';
import '../../features/reports/presentation/pages/customer_report_page.dart';
import '../../features/reports/presentation/pages/employee_report_page.dart';
import '../../features/reports/presentation/pages/inventory_report_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/reports/presentation/pages/sales_report_page.dart';
import '../../features/inventory/presentation/bindings/inventory_binding.dart';
import '../../features/inventory/presentation/bindings/inventory_detail_binding.dart';
import '../../features/inventory/presentation/pages/inventory_adjustment_page.dart';
import '../../features/inventory/presentation/pages/inventory_detail_page.dart';
import '../../features/inventory/presentation/pages/inventory_page.dart';
import '../../features/reservations/presentation/bindings/reservation_detail_binding.dart';
import '../../features/reservations/presentation/bindings/reservation_form_binding.dart';
import '../../features/reservations/presentation/bindings/reservations_binding.dart';
import '../../features/reservations/presentation/pages/reservation_detail_page.dart';
import '../../features/reservations/presentation/pages/reservation_form_page.dart';
import '../../features/reservations/presentation/pages/reservations_page.dart';
import '../../features/tables/presentation/bindings/floor_plan_editor_binding.dart';
import '../../features/tables/presentation/bindings/floor_plans_list_binding.dart';
import '../../features/tables/presentation/bindings/table_status_binding.dart';
import '../../features/tables/presentation/pages/floor_plan_editor_page.dart';
import '../../features/tables/presentation/pages/floor_plans_list_page.dart';
import '../../features/tables/presentation/pages/table_status_page.dart';
import 'app_routes.dart';
import 'route_guards.dart';

/// Configuración de páginas de la aplicación.
///
/// Toda ruta declarada en `AppRoutes` debe estar registrada acá. Las rutas
/// que aún no tienen pantalla propia se registran apuntando a
/// `AppPlaceholderScreen` para evitar 404 fantasma cuando alguien las
/// invoca desde el menú o botones.
///
/// Cuando alguna feature se implemente, se reemplaza el placeholder por la
/// page real + binding correspondiente.
class AppPages {
  AppPages._();

  /// Ruta inicial de la aplicación.
  static const String initial = AppRoutes.splash;

  /// Pantalla mostrada cuando se intenta navegar a una ruta no registrada.
  static final GetPage<dynamic> unknownRoute = GetPage(
    name: '/404',
    page: () => const AppNotFoundScreen(),
    transition: Transition.fadeIn,
  );

  /// Lista de todas las páginas de la aplicación.
  static final List<GetPage> pages = [
    // ==================== AUTH PAGES ====================
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashScreen(),
      binding: SplashBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginScreen(),
      binding: AuthBinding(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.register,
      page: () => const RegisterScreen(),
      binding: AuthBinding(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.forgotPassword,
      page: () => const ForgotPasswordScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.resetPassword,
      page: () => const ResetPasswordScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.verifyEmail,
      page: () => const VerifyEmailScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // ==================== MAIN PAGES ====================
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeScreen(),
      binding: HomeBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.dashboard,
      page: () => const HomeScreen(),
      binding: HomeBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // ==================== ORDERS PAGES ====================
    GetPage(
      name: AppRoutes.orders,
      page: () => const OrdersPage(),
      binding: OrdersBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.ordersList,
      page: () => const OrdersPage(),
      binding: OrdersBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRoutes.unpaidOrders,
      page: () => const UnpaidOrdersPage(),
      binding: OrdersBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRoutes.checklist,
      page: () => const ChecklistScreen(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
    ),
    // Bandeja self-order (pedidos por QR esperando aprobación del mesero).
    // Debe ir ANTES de `/orders/:id` para que GetX no la trate como detalle.
    GetPage(
      name: AppRoutes.pendingReviewOrders,
      page: () => const PendingReviewPage(),
      binding: PendingReviewBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
    ),
    // Admin: gestión de QRs (CRUD + impresión térmica POS).
    GetPage(
      name: AppRoutes.qrTokens,
      page: () => const QrTokensPage(),
      binding: QrTokensBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
    ),
    // Vista previa del QR antes de imprimir (PDF zoomable).
    GetPage(
      name: AppRoutes.qrPreview,
      page: () => const QrPreviewPage(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
    ),
    // Admin: menú del día (qué productos ven los clientes en self-order).
    GetPage(
      name: AppRoutes.menuSchedules,
      page: () => const MenuSchedulesPage(),
      binding: MenuSchedulesBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
    ),
    // Settings: información del negocio (nombre, contacto, NIT) —
    // se imprime en cada recibo térmico.
    GetPage(
      name: AppRoutes.businessInfo,
      page: () => const BusinessInfoScreen(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
    ),
    // IMPORTANTE: rutas específicas ANTES que las parametrizadas.
    // /orders/create debe estar antes de /orders/:id.
    // Pantalla unificada de venta. Mostrador / mesa / takeaway /
    // delivery / cuenta abierta se eligen dentro de la pantalla con
    // un pill superior — sin cambiar de ruta.
    GetPage(
      name: AppRoutes.sell,
      page: () => const SellPage(),
      binding: SellBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 250),
    ),
    // Aliases legacy → redirigen a `/sell`. Mantenemos la ruta para
    // que deep-links viejos (notificaciones, atajos guardados, otros
    // módulos) sigan funcionando sin cambios.
    GetPage(
      name: AppRoutes.createOrder,
      page: () => const SellPage(),
      binding: SellBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 250),
    ),
    GetPage(
      name: AppRoutes.quickSale,
      page: () => const SellPage(),
      binding: SellBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 250),
    ),
    GetPage(
      name: AppRoutes.orderDetail,
      page: () => const OrderDetailPage(),
      binding: OrderDetailBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.tabSessions,
      page: () => const OpenTabsPage(),
      binding: OpenTabsBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.cashRegister,
      page: () => const CashRegisterPage(),
      binding: CashSessionBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.shiftClock,
      page: () => const ShiftClockPage(),
      binding: ShiftBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.roles,
      page: () => const RolesListPage(),
      binding: RoleBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.tabSessionDetail,
      page: () => const TabSessionDetailPage(),
      binding: TabSessionDetailBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.tabSessionPay,
      page: () => const TabSessionPayPage(),
      middlewares: [AuthGuard()],
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    // Edición de metadata de orden (instrucciones, ETA, cliente). Recibe
    // el `id` por `Get.parameters['id']` y opcionalmente la entidad
    // completa en `Get.arguments` para no hacer un GET extra al abrir.
    // Solo visible cuando la orden está en PENDING (lo controla la
    // pantalla de detalle).
    GetPage(
      name: AppRoutes.editOrder,
      page: () => const EditOrderPage(),
      binding: EditOrderBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // ==================== PRODUCTS PAGES ====================
    GetPage(
      name: AppRoutes.products,
      page: () => const ProductsPage(),
      binding: ProductsBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.productsList,
      page: () => const ProductsPage(),
      binding: ProductsBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRoutes.createProduct,
      page: () => const ProductFormPage(),
      binding: ProductFormBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    // /products/edit recibe el producto completo en `Get.arguments` para
    // evitar un GET extra. La ruta paramétrica `editProduct` queda como
    // placeholder hasta tener una pantalla de detalle dedicada.
    GetPage(
      name: '/products/edit',
      page: () {
        final product = Get.arguments;
        return ProductFormPage(productToEdit: product);
      },
      binding: ProductFormBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    // Detalle de producto — lectura. El operario llega acá al tocar una
    // card en la lista; desde acá puede ver toda la info y, si quiere,
    // pasar al form de edición vía el FAB "Editar". El binding inyecta
    // `ProductDetailController` con su `GetProductByIdUseCase`. Si la
    // pantalla anterior pasa el `Product` en `arguments`, se usa de cache
    // mientras el GET resuelve.
    GetPage(
      name: AppRoutes.productDetail,
      page: () => const ProductDetailPage(),
      binding: ProductDetailBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // ==================== MODIFIERS PAGES ====================
    GetPage(
      name: AppRoutes.modifiers,
      page: () => const ModifiersPage(),
      binding: ModifiersBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.modifiersList,
      page: () => const ModifiersPage(),
      binding: ModifiersBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRoutes.createModifier,
      page: () => const ModifierFormPage(),
      binding: ModifierFormBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.editModifier,
      page: () => const ModifierFormPage(),
      binding: ModifierFormBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // ==================== FLAVORS / CREMAS PAGE ====================
    GetPage(
      name: AppRoutes.flavors,
      page: () => const FlavorsPage(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // ==================== CATEGORIES PAGES ====================
    GetPage(
      name: AppRoutes.categories,
      page: () => const CategoriesPage(),
      binding: CategoriesBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.createCategory,
      page: () => const CategoryFormPage(),
      binding: CategoryFormBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.editCategory,
      page: () => const CategoryFormPage(),
      binding: CategoryFormBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.categoryDetail,
      page: () => const CategoryDetailPage(),
      binding: CategoryDetailBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // ==================== TABLES PAGES ====================
    GetPage(
      name: AppRoutes.tables,
      page: () => const FloorPlansListPage(),
      binding: FloorPlansListBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.floorPlanEditor,
      page: () => FloorPlanEditorPage(),
      binding: FloorPlanEditorBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.tableService,
      page: () {
        final floorPlanId = Get.parameters['floorPlanId'];
        if (floorPlanId == null || floorPlanId.isEmpty) {
          // Sin ID válido: rebotamos a la lista de planos.
          Future.microtask(() => Get.offAllNamed(AppRoutes.tables));
          return const AppPlaceholderScreen(
            title: 'Cargando…',
            subtitle: 'Volviendo a la lista',
          );
        }
        return TableStatusPage(
          floorPlanId: floorPlanId,
          floorPlanName: Get.arguments?['floorPlanName'],
        );
      },
      binding: TableStatusBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // ==================== CUSTOMERS PAGES ====================
    GetPage(
      name: AppRoutes.customers,
      page: () => const CustomersPage(),
      binding: CustomersBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.customersList,
      page: () => const CustomersPage(),
      binding: CustomersBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
    ),
    // /customers/create debe ir antes de /customers/:id para que el matcher
    // específico gane sobre la ruta paramétrica.
    GetPage(
      name: AppRoutes.createCustomer,
      page: () => const CustomerFormPage(),
      binding: CustomerFormBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.editCustomer,
      page: () => const CustomerFormPage(),
      binding: CustomerFormBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    // Detalle dedicado de cliente — recibe el id por `Get.parameters['id']`
    // y carga sus addresses y últimas órdenes. El binding inyecta el
    // controller con sus use cases / repo.
    GetPage(
      name: AppRoutes.customerDetail,
      page: () => const CustomerDetailPage(),
      binding: CustomerDetailBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // ==================== EMPLOYEES PAGES ====================
    GetPage(
      name: AppRoutes.employees,
      page: () => const EmployeesPage(),
      binding: EmployeesBinding(),
      middlewares: [AuthGuard(), RoleGuard(requiredRoles: const ["admin", "manager"])],
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRoutes.employeesList,
      page: () => const EmployeesPage(),
      binding: EmployeesBinding(),
      middlewares: [AuthGuard(), RoleGuard(requiredRoles: const ["admin", "manager"])],
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRoutes.employeeDetail,
      page: () => const EmployeeDetailPage(),
      binding: EmployeeDetailBinding(),
      middlewares: [AuthGuard(), RoleGuard(requiredRoles: const ["admin", "manager"])],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.createEmployee,
      page: () => const EmployeeFormPage(),
      binding: EmployeeFormBinding(),
      middlewares: [AuthGuard(), RoleGuard(requiredRoles: const ["admin", "manager"])],
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.editEmployee,
      page: () => const EmployeeFormPage(),
      binding: EmployeeFormBinding(),
      middlewares: [AuthGuard(), RoleGuard(requiredRoles: const ["admin", "manager"])],
      transition: Transition.rightToLeft,
    ),

    // ==================== REPORTS PAGES ====================
    GetPage(
      name: AppRoutes.reports,
      page: () => const ReportsPage(),
      binding: ReportsBinding(),
      middlewares: [AuthGuard(), RoleGuard(requiredRoles: const ["admin", "manager"])],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.salesReport,
      page: () => const SalesReportPage(),
      binding: SalesReportBinding(),
      middlewares: [AuthGuard(), RoleGuard(requiredRoles: const ["admin", "manager"])],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.inventoryReport,
      page: () => const InventoryReportPage(),
      binding: InventoryReportBinding(),
      middlewares: [AuthGuard(), RoleGuard(requiredRoles: const ["admin", "manager"])],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.employeeReport,
      page: () => const EmployeeReportPage(),
      binding: EmployeeReportBinding(),
      middlewares: [AuthGuard(), RoleGuard(requiredRoles: const ["admin", "manager"])],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.customerReport,
      page: () => const CustomerReportPage(),
      binding: CustomerReportBinding(),
      middlewares: [AuthGuard(), RoleGuard(requiredRoles: const ["admin", "manager"])],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // ==================== SETTINGS PAGES ====================
    GetPage(
      name: AppRoutes.settings,
      page: () => const SettingsScreen(),
      middlewares: [AuthGuard(), RoleGuard(requiredRoles: const ["admin", "manager"])],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.profile,
      page: () => const ProfileScreen(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.changePassword,
      page: () => const ChangePasswordScreen(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.businessSettings,
      page: () => const BusinessSettingsScreen(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.printerSettings,
      page: () => const PrinterSettingsScreen(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.notificationSettings,
      page: () => const NotificationSettingsScreen(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.securitySettings,
      page: () => const SecuritySettingsScreen(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.paymentAccountsSettings,
      page: () => const PaymentAccountsSettingsPage(),
      binding: TenantPaymentAccountBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // ==================== INVENTORY PAGES ====================
    GetPage(
      name: AppRoutes.inventory,
      page: () => const InventoryPage(),
      binding: InventoryBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.inventoryList,
      page: () => const InventoryPage(),
      binding: InventoryBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.inventoryDetail,
      page: () => const InventoryDetailPage(),
      binding: InventoryDetailBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.inventoryAdjustment,
      page: () => const InventoryAdjustmentPage(),
      binding: InventoryBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // ==================== RESERVATIONS PAGES ====================
    GetPage(
      name: AppRoutes.reservations,
      page: () => const ReservationsPage(),
      binding: ReservationsBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.reservationsList,
      page: () => const ReservationsPage(),
      binding: ReservationsBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
    ),
    // /reservations/create debe ir antes de /reservations/:id para que el
    // matcher específico gane sobre la ruta paramétrica.
    GetPage(
      name: AppRoutes.createReservation,
      page: () => const ReservationFormPage(),
      binding: ReservationFormBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.editReservation,
      page: () => const ReservationFormPage(),
      binding: ReservationFormBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.reservationDetail,
      page: () => const ReservationDetailPage(),
      binding: ReservationDetailBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // ==================== SUBSCRIPTION PAGES ====================
    GetPage(
      name: AppRoutes.subscription,
      page: () => const SubscriptionPage(),
      binding: SubscriptionBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    // /subscription/plans muestra la misma página por ahora — `current_plan_card`
    // y `trial_banner` la usan como CTA y necesita estar registrada para no
    // disparar 404. La page de comparación dedicada llegará en otra iteración.
    GetPage(
      name: AppRoutes.subscriptionPlans,
      page: () => const SubscriptionPage(),
      binding: SubscriptionBinding(),
      middlewares: [AuthGuard()],
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
  ];
}
