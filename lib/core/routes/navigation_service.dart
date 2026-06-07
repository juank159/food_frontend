import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app_routes.dart';

/// Servicio de navegación con métodos type-safe
///
/// Proporciona métodos convenientes para navegar entre pantallas
/// sin necesidad de recordar los nombres de las rutas.
class NavigationService {
  // Private constructor
  NavigationService._();

  // ==================== AUTH NAVIGATION ====================

  /// Navega a la pantalla de login
  static Future<T?>? toLogin<T>() {
    return Get.offAllNamed<T>(AppRoutes.login);
  }

  /// Navega a la pantalla de registro
  static Future<T?>? toRegister<T>() {
    return Get.toNamed<T>(AppRoutes.register);
  }

  /// Navega a la pantalla de recuperar contraseña
  static Future<T?>? toForgotPassword<T>() {
    return Get.toNamed<T>(AppRoutes.forgotPassword);
  }

  // ==================== MAIN NAVIGATION ====================

  /// Navega a la pantalla principal (home)
  static Future<T?>? toHome<T>({bool clearStack = false}) {
    if (clearStack) {
      return Get.offAllNamed<T>(AppRoutes.home);
    }
    return Get.toNamed<T>(AppRoutes.home);
  }

  /// Navega al dashboard
  static Future<T?>? toDashboard<T>({bool clearStack = false}) {
    if (clearStack) {
      return Get.offAllNamed<T>(AppRoutes.dashboard);
    }
    return Get.toNamed<T>(AppRoutes.dashboard);
  }

  // ==================== ORDERS NAVIGATION ====================

  /// Navega a la lista de órdenes
  static Future<T?>? toOrders<T>() {
    return Get.toNamed<T>(AppRoutes.orders);
  }

  /// Navega a la lista detallada de órdenes
  static Future<T?>? toOrdersList<T>() {
    return Get.toNamed<T>(AppRoutes.ordersList);
  }

  /// Navega al detalle de una orden
  static Future<T?>? toOrderDetail<T>(String orderId) {
    return Get.toNamed<T>(AppRoutes.buildOrderDetail(orderId));
  }

  /// Navega a crear nueva orden
  static Future<T?>? toCreateOrder<T>() {
    return Get.toNamed<T>(AppRoutes.createOrder);
  }

  /// Navega a editar orden
  static Future<T?>? toEditOrder<T>(String orderId) {
    return Get.toNamed<T>(AppRoutes.buildEditOrder(orderId));
  }

  // ==================== PRODUCTS NAVIGATION ====================

  /// Navega a la lista de productos
  static Future<T?>? toProducts<T>() {
    return Get.toNamed<T>(AppRoutes.products);
  }

  /// Navega a la lista detallada de productos
  static Future<T?>? toProductsList<T>() {
    return Get.toNamed<T>(AppRoutes.productsList);
  }

  /// Navega al detalle de un producto.
  ///
  /// `product` (opcional) se pasa como `arguments` para que la página de
  /// detalle muestre algo al instante mientras el GET resuelve. Mismo
  /// patrón que `toEditCategory`.
  static Future<T?>? toProductDetail<T>(String productId, {dynamic product}) {
    return Get.toNamed<T>(
      AppRoutes.buildProductDetail(productId),
      arguments: product,
    );
  }

  /// Navega a crear nuevo producto
  static Future<T?>? toCreateProduct<T>() {
    return Get.toNamed<T>(AppRoutes.createProduct);
  }

  /// Navega a editar producto
  static Future<T?>? toEditProduct<T>(String productId) {
    return Get.toNamed<T>(AppRoutes.buildEditProduct(productId));
  }

  // ==================== CATEGORIES NAVIGATION ====================

  /// Navega a la lista de categorías
  static Future<T?>? toCategories<T>() {
    return Get.toNamed<T>(AppRoutes.categories);
  }

  /// Navega a crear nueva categoría
  static Future<T?>? toCreateCategory<T>() {
    return Get.toNamed<T>(AppRoutes.createCategory);
  }

  /// Navega a editar categoría.
  ///
  /// `category` (opcional) se pasa como `arguments` para que el form pueda
  /// hidratar los campos sin tener que volver a hacer GET por id. Mismo
  /// patrón que `/products/edit`.
  static Future<T?>? toEditCategory<T>(String categoryId, {dynamic category}) {
    return Get.toNamed<T>(
      AppRoutes.buildEditCategory(categoryId),
      arguments: category,
    );
  }

  /// Navega al detalle de una categoría.
  static Future<T?>? toCategoryDetail<T>(String categoryId) {
    return Get.toNamed<T>(AppRoutes.buildCategoryDetail(categoryId));
  }

  // ==================== MODIFIERS NAVIGATION ====================

  /// Navega a la lista de modificadores
  static Future<T?>? toModifiers<T>() {
    return Get.toNamed<T>(AppRoutes.modifiers);
  }

  /// Navega a crear nuevo modificador
  static Future<T?>? toCreateModifier<T>() {
    return Get.toNamed<T>(AppRoutes.createModifier);
  }

  /// Navega a editar modificador
  static Future<T?>? toEditModifier<T>({required dynamic modifier}) {
    return Get.toNamed<T>(AppRoutes.editModifier, arguments: modifier);
  }

  // ==================== TABLES NAVIGATION ====================

  /// Navega al editor de planos de mesas
  static Future<T?>? toTables<T>() {
    return Get.toNamed<T>(AppRoutes.tables);
  }

  /// Navega al editor de planos de mesas (alias)
  static Future<T?>? toFloorPlanEditor<T>() {
    return Get.toNamed<T>(AppRoutes.floorPlanEditor);
  }

  /// Navega a la vista de servicio de mesas
  static Future<T?>? toTableService<T>(String floorPlanId) {
    return Get.toNamed<T>(AppRoutes.buildTableService(floorPlanId));
  }

  // ==================== CUSTOMERS NAVIGATION ====================

  /// Navega a la lista de clientes
  static Future<T?>? toCustomers<T>() {
    return Get.toNamed<T>(AppRoutes.customers);
  }

  /// Navega al detalle de un cliente
  static Future<T?>? toCustomerDetail<T>(String customerId) {
    return Get.toNamed<T>(AppRoutes.buildCustomerDetail(customerId));
  }

  /// Navega a crear nuevo cliente
  static Future<T?>? toCreateCustomer<T>() {
    return Get.toNamed<T>(AppRoutes.createCustomer);
  }

  // ==================== EMPLOYEES NAVIGATION ====================

  /// Navega a la lista de empleados
  static Future<T?>? toEmployees<T>() {
    return Get.toNamed<T>(AppRoutes.employees);
  }

  /// Navega al detalle de un empleado
  static Future<T?>? toEmployeeDetail<T>(String employeeId) {
    return Get.toNamed<T>(AppRoutes.buildEmployeeDetail(employeeId));
  }

  /// Navega a crear nuevo empleado
  static Future<T?>? toCreateEmployee<T>() {
    return Get.toNamed<T>(AppRoutes.createEmployee);
  }

  // ==================== REPORTS NAVIGATION ====================

  /// Navega a reportes
  static Future<T?>? toReports<T>() {
    return Get.toNamed<T>(AppRoutes.reports);
  }

  /// Navega al reporte de ventas
  static Future<T?>? toSalesReport<T>() {
    return Get.toNamed<T>(AppRoutes.salesReport);
  }

  /// Navega al reporte de inventario
  static Future<T?>? toInventoryReport<T>() {
    return Get.toNamed<T>(AppRoutes.inventoryReport);
  }

  // ==================== SETTINGS NAVIGATION ====================

  /// Navega a configuración
  static Future<T?>? toSettings<T>() {
    return Get.toNamed<T>(AppRoutes.settings);
  }

  /// Navega al perfil
  static Future<T?>? toProfile<T>() {
    return Get.toNamed<T>(AppRoutes.profile);
  }

  /// Navega a cambiar contraseña
  static Future<T?>? toChangePassword<T>() {
    return Get.toNamed<T>(AppRoutes.changePassword);
  }

  /// Navega a configuración del negocio
  static Future<T?>? toBusinessSettings<T>() {
    return Get.toNamed<T>(AppRoutes.businessSettings);
  }

  /// Navega a configuración de impresora
  static Future<T?>? toPrinterSettings<T>() {
    return Get.toNamed<T>(AppRoutes.printerSettings);
  }

  // ==================== INVENTORY NAVIGATION ====================

  /// Navega al inventario
  static Future<T?>? toInventory<T>() {
    return Get.toNamed<T>(AppRoutes.inventory);
  }

  /// Navega al detalle de inventario
  static Future<T?>? toInventoryDetail<T>(String inventoryId) {
    return Get.toNamed<T>(AppRoutes.buildInventoryDetail(inventoryId));
  }

  // ==================== RESERVATIONS NAVIGATION ====================

  /// Navega a reservaciones
  static Future<T?>? toReservations<T>() {
    return Get.toNamed<T>(AppRoutes.reservations);
  }

  /// Navega al detalle de reservación
  static Future<T?>? toReservationDetail<T>(String reservationId) {
    return Get.toNamed<T>(AppRoutes.buildReservationDetail(reservationId));
  }

  /// Navega a crear nueva reservación
  static Future<T?>? toCreateReservation<T>() {
    return Get.toNamed<T>(AppRoutes.createReservation);
  }

  // ==================== SUBSCRIPTION NAVIGATION ====================

  /// Navega a la pantalla de suscripción
  static Future<T?>? toSubscription<T>() {
    return Get.toNamed<T>(AppRoutes.subscription);
  }

  /// Navega a la comparación de planes de suscripción
  static Future<T?>? toSubscriptionPlans<T>() {
    return Get.toNamed<T>(AppRoutes.subscriptionPlans);
  }

  // ==================== UTILITY METHODS ====================

  /// Regresa a la pantalla anterior
  static void back<T>({T? result}) {
    Get.back<T>(result: result);
  }

  /// Cierra todas las pantallas y navega a una nueva
  static Future<T?>? offAll<T>(String routeName) {
    return Get.offAllNamed<T>(routeName);
  }

  /// Verifica si se puede regresar
  static bool canGoBack() {
    return Get.key.currentState?.canPop() ?? false;
  }

  /// Obtiene el nombre de la ruta actual
  static String? get currentRoute => Get.currentRoute;

  /// Navega con argumentos
  static Future<T?>? toNamed<T>(String routeName, {dynamic arguments}) {
    return Get.toNamed<T>(routeName, arguments: arguments);
  }

  /// Reemplaza la ruta actual
  static Future<T?>? offNamed<T>(String routeName, {dynamic arguments}) {
    return Get.offNamed<T>(routeName, arguments: arguments);
  }

  /// Elimina todas las rutas hasta llegar a una específica
  static Future<T?>? offNamedUntil<T>(
    String routeName,
    bool Function(RouteSettings) predicate,
  ) {
    return Get.offNamedUntil<T>(
      routeName,
      (route) => predicate(route.settings),
    );
  }

  /// Navega y elimina la ruta anterior
  static Future<T?>? off<T>(String routeName) {
    return Get.offNamed<T>(routeName);
  }
}
