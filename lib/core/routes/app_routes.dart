/// Nombres de rutas de la aplicación
///
/// Esta clase contiene todas las rutas de la aplicación organizadas
/// por módulos para facilitar el mantenimiento y evitar errores de tipeo.
class AppRoutes {
  // Private constructor para prevenir instanciación
  AppRoutes._();

  // ==================== AUTH ROUTES ====================
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String verifyEmail = '/verify-email';

  // ==================== MAIN ROUTES ====================
  static const String home = '/home';
  static const String dashboard = '/dashboard';

  // ==================== QR TOKENS ====================
  static const String qrTokens = '/qr-tokens';
  static const String qrPreview = '/qr-tokens/preview';

  // ==================== MENU SCHEDULES ====================
  static const String menuSchedules = '/menu-schedules';

  // ==================== BUSINESS INFO ====================
  static const String businessInfo = '/settings/business-info';

  // ==================== ORDERS ROUTES ====================
  static const String orders = '/orders';
  static const String ordersList = '/orders/list';
  static const String pendingReviewOrders = '/orders/pending-review';
  // "Por cobrar" — órdenes con saldo pendiente, sin filtro de fecha.
  // Path propio (no bajo /orders/) para no chocar con /orders/:id.
  static const String unpaidOrders = '/unpaid-orders';
  static const String orderDetail = '/orders/:id';
  /// **Pantalla única de venta**. Reemplaza a `createOrder` y
  /// `quickSale` (las dos siguen registradas como alias redirigidos
  /// para no romper deep-links existentes). El destinatario de la
  /// orden (mostrador / mesa / cuenta / takeaway / delivery) se elige
  /// dentro de la pantalla con un pill superior, sin cambiar de ruta.
  static const String sell = '/sell';
  /// Alias legacy — redirigen a `sell` con el modo correcto.
  static const String createOrder = '/orders/create';
  static const String quickSale = '/orders/quick-sale';
  static const String editOrder = '/orders/:id/edit';

  // Cuentas abiertas (TabSessions) — agrupan N tickets por mesa o grupo.
  static const String tabSessions = '/tab-sessions';
  static const String tabSessionDetail = '/tab-sessions/:id';
  static const String tabSessionPay = '/tab-sessions/:id/pay';

  // Caja registradora (apertura / cierre / conciliación)
  static const String cashRegister = '/cash-register';

  // Turnos del empleado logueado (clock-in / clock-out)
  static const String shiftClock = '/shifts/clock';

  // Gestión de roles del equipo (admin/manager)
  static const String roles = '/roles';

  // ==================== PRODUCTS ROUTES ====================
  static const String products = '/products';
  static const String productsList = '/products/list';
  static const String productDetail = '/products/:id';
  static const String createProduct = '/products/create';
  static const String editProduct = '/products/:id/edit';

  // ==================== MODIFIERS ROUTES ====================
  static const String modifiers = '/modifiers';
  static const String modifiersList = '/modifiers/list';
  static const String createModifier = '/modifiers/create';
  static const String editModifier = '/modifiers/edit';

  // ==================== FLAVORS ROUTES ====================
  static const String flavors = '/flavors';

  // ==================== CATEGORIES ROUTES ====================
  static const String categories = '/categories';
  static const String categoriesList = '/categories/list';
  static const String createCategory = '/categories/create';
  static const String editCategory = '/categories/:id/edit';
  static const String categoryDetail = '/categories/:id/detail';

  // ==================== TABLES ROUTES ====================
  /// Ruta principal de mesas (redirige a editor de planos)
  static const String tables = '/tables';

  /// Editor visual de planos de mesas
  static const String floorPlanEditor = '/tables/floor-plan-editor';

  /// Vista de servicio de mesas en tiempo real
  static const String tableService = '/tables/service/:floorPlanId';

  // ==================== CUSTOMERS ROUTES ====================
  static const String customers = '/customers';
  static const String customersList = '/customers/list';
  static const String customerDetail = '/customers/:id';
  static const String createCustomer = '/customers/create';
  static const String editCustomer = '/customers/:id/edit';

  // ==================== EMPLOYEES ROUTES ====================
  static const String employees = '/employees';
  static const String employeesList = '/employees/list';
  static const String employeeDetail = '/employees/:id';
  static const String createEmployee = '/employees/create';
  static const String editEmployee = '/employees/:id/edit';

  // ==================== REPORTS ROUTES ====================
  static const String reports = '/reports';
  static const String salesReport = '/reports/sales';
  static const String inventoryReport = '/reports/inventory';
  static const String employeeReport = '/reports/employees';
  static const String customerReport = '/reports/customers';
  static const String productSalesReport = '/reports/products';

  // ==================== CHECKLIST (lista de compras) ====================
  static const String checklist = '/checklist';

  // ==================== FINANZAS (ganancias / gastos / nómina) ==========
  static const String profit = '/finance/profit';
  static const String expenses = '/finance/expenses';
  static const String payroll = '/finance/payroll';

  // ==================== SETTINGS ROUTES ====================
  static const String settings = '/settings';
  static const String profile = '/settings/profile';
  static const String changePassword = '/settings/change-password';
  static const String businessSettings = '/settings/business';
  static const String printerSettings = '/settings/printer';
  static const String notificationSettings = '/settings/notifications';
  static const String securitySettings = '/settings/security';
  static const String paymentAccountsSettings = '/settings/payment-accounts';

  // ==================== INVENTORY ROUTES ====================
  static const String inventory = '/inventory';
  static const String inventoryList = '/inventory/list';
  static const String inventoryDetail = '/inventory/:id';
  static const String inventoryAdjustment = '/inventory/adjustment';

  // ==================== RESERVATIONS ROUTES ====================
  static const String reservations = '/reservations';
  static const String reservationsList = '/reservations/list';
  static const String reservationDetail = '/reservations/:id';
  static const String createReservation = '/reservations/create';
  static const String editReservation = '/reservations/:id/edit';

  // ==================== SUBSCRIPTION ROUTES ====================
  static const String subscription = '/subscription';
  static const String subscriptionPlans = '/subscription/plans';

  // ==================== HELPER METHODS ====================

  /// Construye una ruta de detalle con el ID
  ///
  /// Ejemplo: AppRoutes.buildOrderDetail('123') => '/orders/123'
  static String buildOrderDetail(String id) => '/orders/$id';

  /// Construye una ruta de edición de orden con el ID
  static String buildEditOrder(String id) => '/orders/$id/edit';

  /// Construye una ruta de detalle de producto con el ID
  static String buildProductDetail(String id) => '/products/$id';

  /// Construye una ruta de edición de producto con el ID
  static String buildEditProduct(String id) => '/products/$id/edit';

  /// Construye una ruta de servicio de mesas con el floor plan ID
  static String buildTableService(String floorPlanId) => '/tables/service/$floorPlanId';

  /// Construye una ruta de detalle de cliente con el ID
  static String buildCustomerDetail(String id) => '/customers/$id';

  /// Construye una ruta de edición de cliente con el ID
  static String buildEditCustomer(String id) => '/customers/$id/edit';

  /// Construye una ruta de detalle de empleado con el ID
  static String buildEmployeeDetail(String id) => '/employees/$id';

  /// Construye una ruta de edición de empleado con el ID
  static String buildEditEmployee(String id) => '/employees/$id/edit';

  /// Construye una ruta de detalle de reservación con el ID
  static String buildReservationDetail(String id) => '/reservations/$id';

  /// Construye una ruta de edición de reservación con el ID
  static String buildEditReservation(String id) => '/reservations/$id/edit';

  /// Construye una ruta de detalle de inventario con el ID
  static String buildInventoryDetail(String id) => '/inventory/$id';

  /// Construye una ruta de edición de categoría con el ID
  static String buildEditCategory(String id) => '/categories/$id/edit';

  /// Construye una ruta de detalle de categoría con el ID
  static String buildCategoryDetail(String id) => '/categories/$id/detail';
}
