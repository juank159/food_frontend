import '../../features/auth/domain/entities/user.dart';

/// Fuente única de verdad sobre **qué muestra la UI a cada rol**.
///
/// **Espejo del modelo de permisos del backend** (lib/database/seeders/
/// roles.seeder.ts del backend). Si el backend cambia los permisos de
/// un rol, este archivo se actualiza para reflejarlo — siempre hay UN
/// SOLO LUGAR donde se decide qué ve cada rol en la app.
///
/// La regla es: **nunca le mostramos al usuario una acción que el
/// backend va a rechazar con 403**. El backend sigue siendo la fuente
/// real de autorización (con `RolesGuard`), esto es la capa UX para
/// que el operario no toque cosas que no le sirven.
///
/// ## Matriz por rol
///
/// | Acción / Rol          | admin | manager | cashier | waiter | kitchen | delivery | bartender |
/// | --------------------- | :---: | :-----: | :-----: | :----: | :-----: | :------: | :-------: |
/// | Vender                |   ✓   |    ✓    |    ✓    |   ✓    |    ·    |    ·     |     ·     |
/// | Cuentas abiertas      |   ✓   |    ✓    |    ✓    |   ✓    |    ·    |    ·     |     ·     |
/// | Estado de mesas       |   ✓   |    ✓    |    ✓    |   ✓    |    ·    |    ·     |     ·     |
/// | Caja                  |   ✓   |    ✓    |    ✓    |   ·    |    ·    |    ·     |     ·     |
/// | Mi turno              |   ✓   |    ✓    |    ✓    |   ✓    |    ✓    |    ✓     |     ✓     |
/// | Pendientes QR         |   ✓   |    ✓    |    ✓    |   ✓    |    ·    |    ·     |     ·     |
/// | Productos             |   ✓   |    ✓    |    ·    |   ·    |    ·    |    ·     |     ·     |
/// | QRs / Menú del día    |   ✓   |    ✓    |    ·    |   ·    |    ·    |    ·     |     ·     |
/// | Reportes / Ventas     |   ✓   |    ✓    |    ·    |   ·    |    ·    |    ·     |     ·     |
/// | Clientes              |   ✓   |    ✓    |    ✓    |   ✓    |    ·    |    ✓     |     ·     |
/// | Reservaciones         |   ✓   |    ✓    |    ✓    |   ✓    |    ·    |    ·     |     ·     |
/// | Empleados             |   ✓   |    ✓    |    ·    |   ·    |    ·    |    ·     |     ·     |
/// | Mesas (admin)         |   ✓   |    ✓    |    ·    |   ·    |    ·    |    ·     |     ·     |
/// | Inventario            |   ✓   |    ✓    |    ·    |   ·    |    ·    |    ·     |     ·     |
/// | Negocio               |   ✓   |    ·    |    ·    |   ·    |    ·    |    ·     |     ·     |
/// | Suscripción           |   ✓   |    ·    |    ·    |   ·    |    ·    |    ·     |     ·     |
/// | Configuración general |   ✓   |    ✓    |    ·    |   ·    |    ·    |    ·     |     ·     |
/// | Mi perfil             |   ✓   |    ✓    |    ✓    |   ✓    |    ✓    |    ✓     |     ✓     |
class UiAccess {
  final String? roleCode;
  const UiAccess._(this.roleCode);

  factory UiAccess.from(User? user) => UiAccess._(user?.roleCode);

  // ── Helpers de rol ──────────────────────────────────────────────

  bool get isAdmin => roleCode == 'admin';
  bool get isManager => roleCode == 'manager';
  bool get isCashier => roleCode == 'cashier';
  bool get isWaiter => roleCode == 'waiter';
  bool get isKitchen => roleCode == 'kitchen';
  bool get isDelivery => roleCode == 'delivery';
  bool get isBartender => roleCode == 'bartender';

  bool get isAdminOrManager => isAdmin || isManager;

  /// Rol que atiende clientes/sala (toma pedidos, cobra, gestiona mesa).
  /// Excluye cocina/delivery/bartender (back-of-house) y back-office.
  bool get isFloorStaff => isCashier || isWaiter;

  // ── Acciones del dashboard / home ───────────────────────────────

  bool get canSell => isAdminOrManager || isFloorStaff;
  bool get canSeeOpenTabs => canSell;
  bool get canSeeTables => canSell;
  bool get canSeeCashRegister => isAdminOrManager || isCashier;
  bool get canSeePendingReview => canSell;
  // Lista de compras / checklist ("lo que hace falta comprar"):
  // admin, gerente y cajero (quienes manejan compras/caja).
  bool get canSeeChecklist => isAdminOrManager || isCashier;

  // ── Gestión / Catálogo ──────────────────────────────────────────

  bool get canSeeProducts => isAdminOrManager;
  bool get canSeeQrTokens => isAdminOrManager;
  bool get canSeeMenuSchedules => isAdminOrManager;

  // ── Reportes ────────────────────────────────────────────────────

  bool get canSeeReports => isAdminOrManager;
  bool get canSeeSalesReport => isAdminOrManager;

  // ── CRM / People ────────────────────────────────────────────────

  /// Quién puede consultar el listado de clientes.
  /// - admin/manager/cashier/waiter: sí (los necesitan para asociar
  ///   tickets, ver historial, búsqueda por teléfono).
  /// - delivery: sí (necesita ver datos del cliente al entregar).
  /// - kitchen/bartender: NO — no interactúan con clientes.
  bool get canSeeCustomers =>
      isAdminOrManager || isFloorStaff || isDelivery;

  /// Quién ve reservaciones.
  /// - admin/manager/cashier/waiter: sí (las atienden).
  /// - el resto no.
  bool get canSeeReservations => isAdminOrManager || isFloorStaff;

  bool get canSeeEmployees => isAdminOrManager;

  /// Edición del layout / floor plans de mesas. NO confundir con "Estado
  /// de mesas" del dashboard, que es operativo. Esto es gestión.
  bool get canSeeTablesAdmin => isAdminOrManager;

  bool get canSeeInventory => isAdminOrManager;

  // ── Settings ────────────────────────────────────────────────────

  /// Configuración del negocio (datos comerciales, info fiscal, etc.).
  /// Solo admin.
  bool get canSeeBusinessSettings => isAdmin;

  /// Página de la suscripción y plan. Solo admin (es la cuenta del dueño).
  bool get canSeeSubscription => isAdmin;

  /// Settings genéricos de la app (tax, tips, etc.). Admin o manager.
  bool get canSeeGeneralSettings => isAdminOrManager;

  /// Perfil del usuario logueado — todos pueden ver el suyo.
  bool get canSeeProfile => true;
}
