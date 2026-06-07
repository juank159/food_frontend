/// API Constants for the Food Platform.
///
/// **URL del backend:** se inyecta en build-time con
/// `--dart-define=API_URL=...`. Si no se pasa, default a localhost
/// (útil en desarrollo). Producción debe pasarla siempre.
///
/// Ejemplos:
///   flutter run --dart-define=API_URL=http://10.0.2.2:3000/api/v1  (Android emu)
///   flutter run --dart-define=API_URL=http://localhost:3000/api/v1 (iOS sim)
///   flutter build apk --dart-define=API_URL=https://api.tudominio.com/api/v1
///   flutter build web --dart-define=API_URL=https://api.tudominio.com/api/v1
class ApiConstants {
  // Base URL — inyectada en build-time. NO hardcodear acá: cambiar
  // este string obliga a recompilar la app, mientras que --dart-define
  // permite tener APKs diferentes (dev/staging/prod) sin tocar código.
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );

  // Auth Endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // Tenant Endpoints
  static const String tenants = '/tenants';
  static String tenantById(String id) => '/tenants/$id';

  // User Endpoints
  static const String users = '/users';
  static String userById(String id) => '/users/$id';

  // Product Endpoints
  static const String products = '/products';
  static String productById(String id) => '/products/$id';
  static const String availableProducts = '/products/available';
  static const String lowStockProducts = '/products/low-stock';
  static String productsByCategory(String categoryId) =>
      '/products/category/$categoryId';
  static String productBySku(String sku) => '/products/sku/$sku';
  static String productVariants(String id) => '/products/$id/variants';
  static const String variants = '/products/variants';
  static String variantById(String id) => '/products/variants/$id';
  static String updateProductStock(String id) => '/products/$id/stock';

  // Modifier Endpoints
  //
  // OJO con la diferencia entre `modifiers` (base) y `modifiersAll` (GET):
  //   - POST  /products/modifiers           → crear modifier
  //   - GET   /products/modifiers/all       → listar todos
  //   - GET   /products/modifiers/:id       → detalle
  //   - PATCH /products/modifiers/:id       → editar
  //   - DELETE /products/modifiers/:id      → eliminar
  // Antes ambos usaban el mismo string `/products/modifiers/all` y por eso
  // el POST de creación se iba al endpoint equivocado y devolvía 404.
  static const String modifiers = '/products/modifiers';
  static const String modifiersAll = '/products/modifiers/all';
  static String modifierById(String id) => '/products/modifiers/$id';
  static const String availableModifiers = '/products/modifiers/available';
  static String modifiersByProduct(String productId) =>
      '/products/modifiers/by-product/$productId';
  static String modifiersByCategory(String categoryId) =>
      '/products/modifiers/by-category/$categoryId';

  // Modifier Group Endpoints
  static const String modifierGroups = '/products/modifier-groups';
  static String modifierGroupById(String id) => '/products/modifier-groups/$id';
  static const String activeModifierGroups = '/products/modifier-groups/active';
  static String modifierGroupsByProduct(String productId) =>
      '/products/modifier-groups/by-product/$productId';
  static String addModifiersToGroup(String groupId) =>
      '/products/modifier-groups/$groupId/modifiers';
  static String removeModifierFromGroup(String groupId, String modifierId) =>
      '/products/modifier-groups/$groupId/modifiers/$modifierId';

  // Category Endpoints
  static const String categories = '/categories';
  static String categoryById(String id) => '/categories/$id';
  static const String categoryTree = '/categories/tree';
  static const String activeCategories = '/categories/active';
  static const String rootCategories = '/categories/root';
  static String subcategories(String parentId) =>
      '/categories/$parentId/subcategories';

  // Order Endpoints
  static const String orders = '/orders';
  static String orderById(String id) => '/orders/$id';
  static String ordersByCustomer(String customerId) =>
      '/orders?customerId=$customerId';
  static String orderStatus(String id) => '/orders/$id/status';
  static const String activeOrders = '/orders/active';
  static String orderByNumber(String orderNumber) =>
      '/orders/number/$orderNumber';

  // Payment Endpoints
  static const String payments = '/payments';
  static String paymentById(String id) => '/payments/$id';
  static String paymentsByOrder(String orderId) => '/payments/order/$orderId';
  static String processOrderPayment(String orderId) =>
      '/payments/order/$orderId/pay';
  static String processSplitPayment(String orderId) =>
      '/payments/order/$orderId/split';
  static String refundPayment(String id) => '/payments/$id/refund';

  // Tenant Payment Accounts (Nequi, Daviplata, Bancolombia, cajas, etc.)
  static const String tenantPaymentAccounts = '/tenant-payment-accounts';
  static String tenantPaymentAccountById(String id) =>
      '/tenant-payment-accounts/$id';
  static String toggleTenantPaymentAccount(String id) =>
      '/tenant-payment-accounts/$id/toggle-active';

  // Tab Sessions (cuentas abiertas — agrupan N tickets por mesa o grupo)
  static const String tabSessions = '/tab-sessions';
  static const String tabSessionsOpen = '/tab-sessions/open';
  static String tabSessionById(String id) => '/tab-sessions/$id';
  static String closeTabSession(String id) => '/tab-sessions/$id/close';
  static String processTabPayment(String tabId) => '/payments/tab/$tabId';

  // Roles (gestión de roles del equipo)
  static const String roles = '/roles';
  static const String rolesActive = '/roles/active';
  static String roleById(String id) => '/roles/$id';
  static String roleByCode(String code) => '/roles/code/$code';

  // Shifts (clock-in/clock-out de empleados)
  static const String shifts = '/shifts';
  static const String shiftClockIn = '/shifts/clock-in';
  static const String shiftClockOut = '/shifts/clock-out';
  static const String shiftMyCurrent = '/shifts/me/current';
  static const String shiftMine = '/shifts/me';
  static const String shiftActive = '/shifts/active';
  static String shiftsByUser(String userId) => '/shifts/user/$userId';

  // Cash Sessions (apertura y cierre de caja registradora)
  static const String cashSessions = '/cash-sessions';
  static const String cashSessionOpen = '/cash-sessions/open';
  static const String cashSessionCurrent = '/cash-sessions/current';
  static String cashSessionById(String id) => '/cash-sessions/$id';
  static String cashSessionReport(String id) =>
      '/cash-sessions/$id/report';
  static String closeCashSession(String id) =>
      '/cash-sessions/$id/close';

  // Table Endpoints
  static const String tables = '/tables';
  static String tableById(String id) => '/tables/$id';
  static const String availableTables = '/tables/available';
  static const String occupiedTables = '/tables/occupied';
  static String tablesByStatus(String status) => '/tables?status=$status';
  static String tablesByZone(String zone) => '/tables?zone=$zone';
  static String tableStatus(String id) => '/tables/$id/status';
  static String tablePosition(String id) => '/tables/$id/position';
  static String tableOrders(String id) => '/tables/$id/orders';
  static const String tableLayout = '/tables/layout';

  // Customer Endpoints
  static const String customers = '/customers';
  static String customerById(String id) => '/customers/$id';

  // Reservation Endpoints
  static const String reservations = '/reservations';
  static String reservationById(String id) => '/reservations/$id';
  static const String upcomingReservations = '/reservations/upcoming';
  static String reservationStatus(String id) => '/reservations/$id/status';
  static String cancelReservationEndpoint(String id) =>
      '/reservations/$id/cancel';

  // Subscription Endpoints
  static const String subscriptionPlans = '/subscriptions/plans';
  static const String currentSubscription = '/subscriptions/current';
  static const String subscriptionUsage = '/subscriptions/usage';
  static const String changePlan = '/subscriptions/change-plan';
  static const String cancelSubscription = '/subscriptions/cancel';
  static const String checkFeature = '/subscriptions/check-feature';
  static const String checkLimit = '/subscriptions/check-limit';

  // HTTP Headers
  static const String authorizationHeader = 'Authorization';
  static const String contentTypeHeader = 'Content-Type';
  static const String tenantHeader = 'x-tenant-id';
  static const String tenantSubdomainHeader = 'x-tenant-subdomain';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';
  static const String tenantIdKey = 'tenant_id';
  static const String tenantSchemaKey = 'tenant_schema';

  /// Último subdomain + email usado para login. Se conservan después de
  /// logout para precargar el formulario en el próximo inicio — la
  /// CONTRASEÑA no se guarda nunca (eso es responsabilidad del
  /// password manager del sistema, no nuestra).
  static const String lastLoginSubdomainKey = 'last_login_subdomain';
  static const String lastLoginEmailKey = 'last_login_email';
}
