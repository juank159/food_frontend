import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/get_current_user_usecase.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/logout_usecase.dart';
import '../../features/auth/domain/usecases/register_usecase.dart';
import '../../features/categories/data/datasources/category_remote_datasource.dart';
import '../../features/flavors/data/datasources/flavor_remote_datasource.dart';
import '../../features/categories/data/repositories/category_repository_impl.dart';
import '../../features/categories/domain/repositories/category_repository.dart';
import '../../features/categories/domain/usecases/create_category_usecase.dart';
import '../../features/categories/domain/usecases/get_active_categories_usecase.dart';
import '../../features/categories/domain/usecases/get_categories_usecase.dart';
import '../../features/categories/domain/usecases/get_category_by_id_usecase.dart';
import '../../features/categories/domain/usecases/get_category_tree_usecase.dart';
import '../../features/categories/domain/usecases/update_category_usecase.dart';
import '../../features/customers/data/datasources/customer_remote_datasource.dart';
import '../../features/customers/data/repositories/customer_repository_impl.dart';
import '../../features/customers/domain/repositories/customer_repository.dart';
import '../../features/customers/domain/usecases/create_customer_usecase.dart';
import '../../features/customers/domain/usecases/delete_customer_usecase.dart';
import '../../features/customers/domain/usecases/get_customer_by_id_usecase.dart';
import '../../features/customers/domain/usecases/get_customer_statistics_usecase.dart';
import '../../features/customers/domain/usecases/get_customers_usecase.dart';
import '../../features/customers/domain/usecases/update_customer_usecase.dart';
import '../../features/employees/data/datasources/employee_remote_datasource.dart';
import '../../features/employees/data/repositories/employee_repository_impl.dart';
import '../../features/employees/domain/repositories/employee_repository.dart';
import '../../features/employees/domain/usecases/activate_employee_usecase.dart';
import '../../features/employees/domain/usecases/create_employee_usecase.dart';
import '../../features/employees/domain/usecases/delete_employee_usecase.dart';
import '../../features/employees/domain/usecases/get_active_employees_usecase.dart';
import '../../features/employees/domain/usecases/get_employee_by_id_usecase.dart';
import '../../features/employees/domain/usecases/get_employees_usecase.dart';
import '../../features/employees/domain/usecases/suspend_employee_usecase.dart';
import '../../features/employees/domain/usecases/update_employee_usecase.dart';
import '../../features/orders/data/datasources/order_remote_datasource.dart';
import '../../features/qr_tokens/data/qr_tokens_remote_datasource.dart';
import '../../features/thermal_print/data/thermal_print_service.dart';
import '../../features/menu_schedules/data/menu_schedules_remote_datasource.dart';
import '../../features/printer_configs/data/printer_configs_remote_datasource.dart';
import '../../features/orders/data/repositories/order_repository_impl.dart';
import '../../features/orders/domain/repositories/order_repository.dart';
import '../../features/orders/domain/usecases/create_order_usecase.dart';
import '../../features/orders/domain/usecases/get_active_orders_usecase.dart';
import '../../features/orders/domain/usecases/get_order_by_id_usecase.dart';
import '../../features/orders/domain/usecases/get_orders_usecase.dart';
import '../../features/orders/domain/usecases/update_order_item_status_usecase.dart';
import '../../features/orders/domain/usecases/update_order_status_usecase.dart';
import '../../features/orders/domain/usecases/update_order_usecase.dart';
import '../../features/products/data/datasources/product_remote_datasource.dart';
import '../../features/products/data/repositories/product_repository_impl.dart';
import '../../features/products/domain/repositories/product_repository.dart';
import '../../features/products/domain/usecases/get_available_products_usecase.dart';
import '../../features/products/domain/usecases/get_product_by_id_usecase.dart';
import '../../features/products/domain/usecases/get_products_usecase.dart';
import '../../features/products/domain/usecases/create_product_usecase.dart';
import '../../features/products/domain/usecases/update_product_usecase.dart';
import '../../features/products/domain/usecases/delete_product_usecase.dart';
import '../../features/products/domain/usecases/create_variant_usecase.dart';
import '../../features/products/domain/usecases/update_variant_usecase.dart';
import '../../features/products/domain/usecases/delete_variant_usecase.dart';
import '../../features/products/domain/usecases/get_modifiers_usecase.dart';
import '../../features/products/domain/usecases/get_modifier_by_id_usecase.dart';
import '../../features/products/domain/usecases/create_modifier_usecase.dart';
import '../../features/products/domain/usecases/update_modifier_usecase.dart';
import '../../features/products/domain/usecases/delete_modifier_usecase.dart';
import '../../features/products/domain/usecases/get_modifier_groups_usecase.dart';
import '../../features/products/domain/usecases/create_modifier_group_usecase.dart';
import '../../features/products/domain/usecases/update_modifier_group_usecase.dart';
import '../../features/products/domain/usecases/delete_modifier_group_usecase.dart';
import '../../features/products/domain/usecases/add_modifiers_to_group_usecase.dart';
import '../../features/products/domain/usecases/remove_modifier_from_group_usecase.dart';
import '../../features/tables/data/datasources/floor_plan_datasource.dart';
import '../../features/tables/data/datasources/table_remote_datasource.dart';
import '../../features/tables/data/datasources/table_status_datasource.dart';
import '../../features/tables/data/repositories/floor_plan_repository_impl.dart';
import '../../features/tables/data/repositories/table_repository_impl.dart';
import '../../features/tables/data/repositories/table_status_repository.dart';
import '../../features/tables/domain/repositories/floor_plan_repository.dart';
import '../../features/tables/domain/repositories/table_repository.dart';
import '../../features/tables/domain/usecases/create_table_usecase.dart';
import '../../features/tables/domain/usecases/get_available_tables_usecase.dart';
import '../../features/tables/domain/usecases/get_table_by_id_usecase.dart';
import '../../features/tables/domain/usecases/get_tables_usecase.dart';
import '../../features/tables/domain/usecases/occupy_table_usecase.dart';
import '../../features/tables/domain/usecases/update_table_status_usecase.dart';
import '../../features/tables/domain/usecases/update_table_position_usecase.dart';
import '../../features/tables/domain/usecases/update_table_usecase.dart';
import '../../features/payments/data/datasources/payment_remote_datasource.dart';
import '../../features/payments/data/repositories/payment_repository_impl.dart';
import '../../features/payments/domain/repositories/payment_repository.dart';
import '../../features/payments/domain/usecases/get_payments_by_order_usecase.dart';
import '../../features/payments/domain/usecases/create_payment_usecase.dart';
import '../../features/payments/domain/usecases/process_order_payment_usecase.dart';
import '../../features/payments/domain/usecases/refund_payment_usecase.dart';
import '../../features/payments/domain/usecases/process_tab_payment_usecase.dart';
import '../../features/tab_sessions/data/datasources/tab_session_remote_datasource.dart';
import '../../features/tab_sessions/data/repositories/tab_session_repository_impl.dart';
import '../../features/tab_sessions/domain/repositories/tab_session_repository.dart';
import '../../features/tab_sessions/domain/usecases/tab_session_usecases.dart';
import '../../features/cash_sessions/data/datasources/cash_session_remote_datasource.dart';
import '../../features/cash_sessions/data/repositories/cash_session_repository_impl.dart';
import '../../features/cash_sessions/domain/repositories/cash_session_repository.dart';
import '../../features/cash_sessions/domain/usecases/cash_session_usecases.dart';
import '../../features/roles/data/datasources/role_remote_datasource.dart';
import '../../features/roles/data/repositories/role_repository_impl.dart';
import '../../features/roles/domain/repositories/role_repository.dart';
import '../../features/roles/domain/usecases/role_usecases.dart';
import '../../features/shifts/data/datasources/shift_remote_datasource.dart';
import '../../features/shifts/data/repositories/shift_repository_impl.dart';
import '../../features/shifts/domain/repositories/shift_repository.dart';
import '../../features/shifts/domain/usecases/shift_usecases.dart';
import '../../features/tenant_payment_accounts/data/datasources/tenant_payment_account_remote_datasource.dart';
import '../../features/tenant_payment_accounts/data/repositories/tenant_payment_account_repository_impl.dart';
import '../../features/tenant_payment_accounts/domain/repositories/tenant_payment_account_repository.dart';
import '../../features/tenant_payment_accounts/domain/usecases/tenant_payment_account_usecases.dart';
import '../../features/subscriptions/data/datasources/subscription_remote_datasource.dart';
import '../../features/subscriptions/data/repositories/subscription_repository_impl.dart';
import '../../features/subscriptions/domain/repositories/subscription_repository.dart';
import '../../features/subscriptions/domain/usecases/cancel_subscription_usecase.dart';
import '../../features/subscriptions/domain/usecases/change_plan_usecase.dart';
import '../../features/subscriptions/domain/usecases/get_current_subscription_usecase.dart';
import '../../features/subscriptions/domain/usecases/get_plans_usecase.dart';
import '../../features/subscriptions/domain/usecases/get_usage_usecase.dart';
import '../../features/reports/data/datasources/reports_remote_datasource.dart';
import '../../features/reports/data/repositories/reports_repository_impl.dart';
import '../../features/reports/domain/repositories/reports_repository.dart';
import '../../features/reports/domain/usecases/get_customer_report_usecase.dart';
import '../../features/reports/domain/usecases/get_employee_report_usecase.dart';
import '../../features/reports/domain/usecases/get_inventory_report_usecase.dart';
import '../../features/reports/domain/usecases/get_sales_report_usecase.dart';
import '../../features/inventory/data/datasources/inventory_remote_datasource.dart';
import '../../features/inventory/data/repositories/inventory_repository_impl.dart';
import '../../features/inventory/domain/repositories/inventory_repository.dart';
import '../../features/inventory/domain/usecases/adjust_stock_usecase.dart';
import '../../features/inventory/domain/usecases/get_inventory_usecase.dart';
import '../../features/reservations/data/datasources/reservation_remote_datasource.dart';
import '../../features/reservations/data/repositories/reservation_repository_impl.dart';
import '../../features/reservations/domain/repositories/reservation_repository.dart';
import '../../features/reservations/domain/usecases/cancel_reservation_usecase.dart';
import '../../features/reservations/domain/usecases/create_reservation_usecase.dart';
import '../../features/reservations/domain/usecases/delete_reservation_usecase.dart';
import '../../features/reservations/domain/usecases/get_reservation_by_id_usecase.dart';
import '../../features/reservations/domain/usecases/get_reservations_usecase.dart';
import '../../features/reservations/domain/usecases/get_upcoming_reservations_usecase.dart';
import '../../features/reservations/domain/usecases/update_reservation_status_usecase.dart';
import '../../features/reservations/domain/usecases/update_reservation_usecase.dart';
import '../config/constants/api_constants.dart';
import '../network/network_info.dart';

final sl = GetIt.instance;

/// Initialize all dependencies
Future<void> init() async {
  // ========================================
  // Features - Auth
  // ========================================

  // Use Cases
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => RegisterUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));

  // Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Data Sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(dio: sl()),
  );

  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(
      secureStorage: sl(),
      sharedPreferences: sl(),
    ),
  );

  // ========================================
  // Features - Products
  // ========================================

  // Use Cases
  sl.registerLazySingleton(() => GetProductsUseCase(sl()));
  sl.registerLazySingleton(() => GetProductByIdUseCase(sl()));
  sl.registerLazySingleton(() => GetAvailableProductsUseCase(sl()));
  sl.registerLazySingleton(() => CreateProductUseCase(sl()));
  sl.registerLazySingleton(() => UpdateProductUseCase(sl()));
  sl.registerLazySingleton(() => DeleteProductUseCase(sl()));
  sl.registerLazySingleton(() => CreateVariantUseCase(sl()));
  sl.registerLazySingleton(() => UpdateVariantUseCase(sl()));
  sl.registerLazySingleton(() => DeleteVariantUseCase(sl()));

  // Modifier Use Cases
  sl.registerLazySingleton(() => GetModifiersUseCase(sl()));
  sl.registerLazySingleton(() => GetModifierByIdUseCase(sl()));
  sl.registerLazySingleton(() => CreateModifierUseCase(sl()));
  sl.registerLazySingleton(() => UpdateModifierUseCase(sl()));
  sl.registerLazySingleton(() => DeleteModifierUseCase(sl()));

  // Modifier Group Use Cases
  sl.registerLazySingleton(() => GetModifierGroupsUseCase(sl()));
  sl.registerLazySingleton(() => CreateModifierGroupUseCase(sl()));
  sl.registerLazySingleton(() => UpdateModifierGroupUseCase(sl()));
  sl.registerLazySingleton(() => DeleteModifierGroupUseCase(sl()));
  sl.registerLazySingleton(() => AddModifiersToGroupUseCase(sl()));
  sl.registerLazySingleton(() => RemoveModifierFromGroupUseCase(sl()));

  // Repository
  sl.registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Data Sources
  sl.registerLazySingleton<ProductRemoteDataSource>(
    () => ProductRemoteDataSourceImpl(dio: sl()),
  );

  // ========================================
  // Features - Categories
  // ========================================

  // Use Cases
  sl.registerLazySingleton(() => GetCategoriesUseCase(sl()));
  sl.registerLazySingleton(() => GetCategoryTreeUseCase(sl()));
  sl.registerLazySingleton(() => GetActiveCategoriesUseCase(sl()));
  sl.registerLazySingleton(() => GetCategoryByIdUseCase(sl()));
  sl.registerLazySingleton(() => CreateCategoryUseCase(sl()));
  sl.registerLazySingleton(() => UpdateCategoryUseCase(sl()));

  // Repository
  sl.registerLazySingleton<CategoryRepository>(
    () => CategoryRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Data Sources
  sl.registerLazySingleton<CategoryRemoteDataSource>(
    () => CategoryRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<FlavorRemoteDataSource>(
    () => FlavorRemoteDataSourceImpl(dio: sl()),
  );

  // ========================================
  // Features - Customers
  // ========================================

  // Use Cases
  sl.registerLazySingleton(() => GetCustomersUseCase(sl()));
  sl.registerLazySingleton(() => GetCustomerByIdUseCase(sl()));
  sl.registerLazySingleton(() => CreateCustomerUseCase(sl()));
  sl.registerLazySingleton(() => UpdateCustomerUseCase(sl()));
  sl.registerLazySingleton(() => DeleteCustomerUseCase(sl()));
  sl.registerLazySingleton(() => GetCustomerStatisticsUseCase(sl()));

  // Repository
  sl.registerLazySingleton<CustomerRepository>(
    () => CustomerRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Data Sources
  sl.registerLazySingleton<CustomerRemoteDataSource>(
    () => CustomerRemoteDataSourceImpl(dio: sl()),
  );

  // ========================================
  // Features - Employees
  // ========================================

  // Use Cases
  sl.registerLazySingleton(() => GetEmployeesUseCase(sl()));
  sl.registerLazySingleton(() => GetActiveEmployeesUseCase(sl()));
  sl.registerLazySingleton(() => GetEmployeeByIdUseCase(sl()));
  sl.registerLazySingleton(() => CreateEmployeeUseCase(sl()));
  sl.registerLazySingleton(() => UpdateEmployeeUseCase(sl()));
  sl.registerLazySingleton(() => SuspendEmployeeUseCase(sl()));
  sl.registerLazySingleton(() => ActivateEmployeeUseCase(sl()));
  sl.registerLazySingleton(() => DeleteEmployeeUseCase(sl()));

  // Repository
  sl.registerLazySingleton<EmployeeRepository>(
    () => EmployeeRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Data Sources
  sl.registerLazySingleton<EmployeeRemoteDataSource>(
    () => EmployeeRemoteDataSourceImpl(dio: sl()),
  );

  // ========================================
  // Features - Orders
  // ========================================

  // Use Cases
  sl.registerLazySingleton(() => GetOrdersUseCase(sl()));
  sl.registerLazySingleton(() => GetOrderByIdUseCase(sl()));
  sl.registerLazySingleton(() => GetActiveOrdersUseCase(sl()));
  sl.registerLazySingleton(() => CreateOrderUseCase(sl()));
  sl.registerLazySingleton(() => UpdateOrderStatusUseCase(sl()));
  sl.registerLazySingleton(() => UpdateOrderItemStatusUseCase(sl()));
  sl.registerLazySingleton(() => UpdateOrderUseCase(sl()));

  // Repository
  sl.registerLazySingleton<OrderRepository>(
    () => OrderRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Data Sources
  sl.registerLazySingleton<OrderRemoteDataSource>(
    () => OrderRemoteDataSourceImpl(dio: sl()),
  );

  // ========================================
  // Features - QR Tokens + Thermal Print (self-order)
  // ========================================
  // Las features de QR Tokens y Thermal Print no usan use-cases ni
  // repository abstracto — son data layers contenidas con datasource
  // directo desde el controller. Simplifica el setup y no compromete
  // testabilidad (los datasources son mockeables).
  sl.registerLazySingleton(
    () => QrTokensRemoteDataSource(dio: sl()),
  );
  sl.registerLazySingleton(
    () => ThermalPrintService(dio: sl()),
  );
  sl.registerLazySingleton(
    () => MenuSchedulesRemoteDataSource(dio: sl()),
  );
  sl.registerLazySingleton(
    () => PrinterConfigsRemoteDataSource(dio: sl()),
  );

  // ========================================
  // Features - Tables
  // ========================================

  // Use Cases
  sl.registerLazySingleton(() => GetTablesUseCase(sl()));
  sl.registerLazySingleton(() => GetTableByIdUseCase(sl()));
  sl.registerLazySingleton(() => GetAvailableTablesUseCase(sl()));
  sl.registerLazySingleton(() => CreateTableUseCase(sl()));
  sl.registerLazySingleton(() => UpdateTableUseCase(sl()));
  sl.registerLazySingleton(() => UpdateTableStatusUseCase(sl()));
  sl.registerLazySingleton(() => OccupyTableUseCase(sl()));
  sl.registerLazySingleton(() => UpdateTablePositionUseCase(sl()));

  // Repository
  sl.registerLazySingleton<TableRepository>(
    () => TableRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Data Sources
  sl.registerLazySingleton<TableRemoteDataSource>(
    () => TableRemoteDataSourceImpl(dio: sl()),
  );

  // Table Status (separate datasource/repository — used by the order create
  // flow's TableSelectorWidget, registered here so GetIt can resolve it).
  sl.registerLazySingleton<TableStatusDatasource>(
    () => TableStatusDatasourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<TableStatusRepository>(
    () => TableStatusRepositoryImpl(datasource: sl()),
  );

  // Floor Plans — necesario en el TableSelectorWidget para listar planos
  // desde el formulario de creación de orden.
  sl.registerLazySingleton<FloorPlanDataSource>(
    () => FloorPlanDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<FloorPlanRepository>(
    () => FloorPlanRepositoryImpl(dataSource: sl()),
  );

  // ========================================
  // Features - Payments
  // ========================================

  // Use Cases
  sl.registerLazySingleton(() => ProcessOrderPaymentUseCase(sl()));
  sl.registerLazySingleton(() => GetPaymentsByOrderUseCase(sl()));
  sl.registerLazySingleton(() => RefundPaymentUseCase(sl()));
  sl.registerLazySingleton(() => ProcessTabPaymentUseCase(sl()));
  sl.registerLazySingleton(() => CreatePaymentUseCase(sl()));

  // Repository
  sl.registerLazySingleton<PaymentRepository>(
    () => PaymentRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Data Sources
  sl.registerLazySingleton<PaymentRemoteDataSource>(
    () => PaymentRemoteDataSourceImpl(dio: sl()),
  );

  // ========================================
  // Features - Tab Sessions (cuentas abiertas)
  // ========================================
  sl.registerLazySingleton(() => TabSessionUseCases(sl()));
  sl.registerLazySingleton<TabSessionRepository>(
    () => TabSessionRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton<TabSessionRemoteDataSource>(
    () => TabSessionRemoteDataSourceImpl(dio: sl()),
  );

  // ========================================
  // Features - Roles (gestión de roles y permisos)
  // ========================================
  sl.registerLazySingleton(() => RoleUseCases(sl()));
  sl.registerLazySingleton<RoleRepository>(
    () => RoleRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton<RoleRemoteDataSource>(
    () => RoleRemoteDataSourceImpl(dio: sl()),
  );

  // ========================================
  // Features - Shifts (turnos de empleados)
  // ========================================
  sl.registerLazySingleton(() => ShiftUseCases(sl()));
  sl.registerLazySingleton<ShiftRepository>(
    () => ShiftRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton<ShiftRemoteDataSource>(
    () => ShiftRemoteDataSourceImpl(dio: sl()),
  );

  // ========================================
  // Features - Cash Sessions (apertura y cierre de caja)
  // ========================================
  sl.registerLazySingleton(() => CashSessionUseCases(sl()));
  sl.registerLazySingleton<CashSessionRepository>(
    () => CashSessionRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton<CashSessionRemoteDataSource>(
    () => CashSessionRemoteDataSourceImpl(dio: sl()),
  );

  // ========================================
  // Features - Tenant Payment Accounts
  // ========================================
  sl.registerLazySingleton(() => TenantPaymentAccountUseCases(sl()));
  sl.registerLazySingleton<TenantPaymentAccountRepository>(
    () => TenantPaymentAccountRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton<TenantPaymentAccountRemoteDataSource>(
    () => TenantPaymentAccountRemoteDataSourceImpl(dio: sl()),
  );

  // ========================================
  // Features - Subscriptions
  // ========================================

  // Use Cases
  sl.registerLazySingleton(() => GetPlansUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentSubscriptionUseCase(sl()));
  sl.registerLazySingleton(() => GetUsageUseCase(sl()));
  sl.registerLazySingleton(() => ChangePlanUseCase(sl()));
  sl.registerLazySingleton(() => CancelSubscriptionUseCase(sl()));

  // Repository
  sl.registerLazySingleton<SubscriptionRepository>(
    () => SubscriptionRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Data Source
  sl.registerLazySingleton<SubscriptionRemoteDataSource>(
    () => SubscriptionRemoteDataSourceImpl(dio: sl()),
  );

  // ========================================
  // Features - Reports
  // ========================================

  // Use Cases
  sl.registerLazySingleton(() => GetSalesReportUseCase(sl()));
  sl.registerLazySingleton(() => GetInventoryReportUseCase(sl()));
  sl.registerLazySingleton(() => GetEmployeeReportUseCase(sl()));
  sl.registerLazySingleton(() => GetCustomerReportUseCase(sl()));

  // Repository
  sl.registerLazySingleton<ReportsRepository>(
    () => ReportsRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Data Source
  sl.registerLazySingleton<ReportsRemoteDataSource>(
    () => ReportsRemoteDataSourceImpl(dio: sl()),
  );

  // ========================================
  // Features - Inventory
  // ========================================

  // Use Cases
  sl.registerLazySingleton(() => GetInventoryUseCase(sl()));
  sl.registerLazySingleton(() => AdjustStockUseCase(sl()));

  // Repository
  sl.registerLazySingleton<InventoryRepository>(
    () => InventoryRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Data Source
  sl.registerLazySingleton<InventoryRemoteDataSource>(
    () => InventoryRemoteDataSourceImpl(dio: sl()),
  );

  // ========================================
  // Features - Reservations
  // ========================================

  // Use Cases
  sl.registerLazySingleton(() => GetReservationsUseCase(sl()));
  sl.registerLazySingleton(() => GetReservationByIdUseCase(sl()));
  sl.registerLazySingleton(() => GetUpcomingReservationsUseCase(sl()));
  sl.registerLazySingleton(() => CreateReservationUseCase(sl()));
  sl.registerLazySingleton(() => UpdateReservationUseCase(sl()));
  sl.registerLazySingleton(() => UpdateReservationStatusUseCase(sl()));
  sl.registerLazySingleton(() => CancelReservationUseCase(sl()));
  sl.registerLazySingleton(() => DeleteReservationUseCase(sl()));

  // Repository
  sl.registerLazySingleton<ReservationRepository>(
    () => ReservationRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Data Source
  sl.registerLazySingleton<ReservationRemoteDataSource>(
    () => ReservationRemoteDataSourceImpl(dio: sl()),
  );

  // ========================================
  // Core
  // ========================================

  // Network Info — InternetConnectionChecker is unavailable on web
  sl.registerLazySingleton<NetworkInfo>(
    () => kIsWeb ? NetworkInfoImpl() : NetworkInfoImpl(sl()),
  );

  // ========================================
  // External
  // ========================================

  // Dio
  sl.registerLazySingleton<Dio>(() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        sendTimeout: ApiConstants.sendTimeout,
        headers: {
          ApiConstants.contentTypeHeader: 'application/json',
        },
      ),
    );

    // Separate Dio used to call /auth/refresh — it must NOT go through this
    // interceptor or a refresh that returns 401 would loop forever.
    final refreshDio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {
          ApiConstants.contentTypeHeader: 'application/json',
        },
      ),
    );

    // Single in-flight refresh future. If many requests fail with 401 at the
    // same time, they all await the same refresh call instead of hammering
    // the endpoint.
    Future<String?>? pendingRefresh;

    Future<String?> refreshAccessToken() {
      pendingRefresh ??= () async {
        try {
          final storage = sl<AuthLocalDataSource>();
          final refreshToken = await storage.getRefreshToken();
          if (refreshToken == null) return null;

          final response = await refreshDio.post(
            ApiConstants.refreshToken,
            data: {'refresh_token': refreshToken},
          );

          if (response.statusCode != 200) return null;

          final newAccess = response.data['access_token'] as String?;
          final newRefresh = response.data['refresh_token'] as String?;
          if (newAccess == null || newRefresh == null) return null;

          await storage.cacheTokens(
            accessToken: newAccess,
            refreshToken: newRefresh,
          );
          return newAccess;
        } catch (_) {
          return null;
        } finally {
          pendingRefresh = null;
        }
      }();
      return pendingRefresh!;
    }

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final path = options.path;

          // Don't add auth token to login/register endpoints
          final isAuthEndpoint = path.contains('/auth/login') ||
                                 path.contains('/auth/register') ||
                                 path.contains('/auth/refresh') ||
                                 path.contains('/tenants');

          if (!isAuthEndpoint) {
            final token = await sl<AuthLocalDataSource>().getAccessToken();
            if (token != null) {
              options.headers[ApiConstants.authorizationHeader] = 'Bearer $token';
            }

            if (!options.headers.containsKey(ApiConstants.tenantHeader)) {
              final tenantId = await sl<AuthLocalDataSource>().getTenantId();
              if (tenantId != null) {
                options.headers[ApiConstants.tenantHeader] = tenantId;
              }
            }
          }

          return handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final isUnauthorized = status == 401;
          final originalPath = error.requestOptions.path;
          // Skip retry for auth endpoints to avoid loops, and for requests
          // we've already retried once.
          final isAuthEndpoint = originalPath.contains('/auth/login') ||
                                 originalPath.contains('/auth/register') ||
                                 originalPath.contains('/auth/refresh');
          final alreadyRetried =
              error.requestOptions.extra['_retried'] == true;

          // 403 con el mensaje "Token sin información de rol" significa
          // que la app está usando un access_token emitido por una build
          // del backend anterior al fix de `role_code` en refresh. El
          // refresh no puede recuperar la info — el refresh_token
          // tampoco la tiene. Único camino: forzar logout y mandar al
          // user a /login para que emita tokens frescos.
          if (status == 403 && !isAuthEndpoint) {
            final body = error.response?.data;
            final msg =
                body is Map ? body['message']?.toString() ?? '' : '';
            if (msg.contains('Token sin información de rol')) {
              await sl<AuthLocalDataSource>().clearAll();
              // Mandamos al user a /login para emitir tokens frescos.
              // `Get.context` puede ser null si Dio dispara antes de que
              // el router esté listo — en ese caso, dejamos el error
              // burbujear y la próxima navegación caerá en /login por el
              // guard de auth que lee el storage vacío.
              if (Get.context != null) {
                Get.offAllNamed('/login');
              }
              return handler.next(error);
            }
          }

          // 429 (rate limit): si el server pide esperar poco, reintentamos
          // UNA vez tras la espera — así un pico transitorio no se ve como
          // error. Si la espera es larga, dejamos fallar (el watcher de
          // polls lo traga; una acción puntual mostrará error, raro tras
          // subir los límites por rol en el backend).
          if (status == 429 && !alreadyRetried && !isAuthEndpoint) {
            final retryAfterRaw =
                error.response?.headers.value('retry-after');
            final retryAfter = int.tryParse(retryAfterRaw ?? '');
            if (retryAfter != null && retryAfter > 0 && retryAfter <= 2) {
              await Future.delayed(Duration(seconds: retryAfter));
              final retryOptions = error.requestOptions
                ..extra['_retried'] = true;
              try {
                final response = await dio.fetch(retryOptions);
                return handler.resolve(response);
              } catch (e) {
                return handler.next(e is DioException ? e : error);
              }
            }
            return handler.next(error);
          }

          if (!isUnauthorized || isAuthEndpoint || alreadyRetried) {
            return handler.next(error);
          }

          final newAccessToken = await refreshAccessToken();
          if (newAccessToken == null) {
            // Refresh failed — clear tokens so guards send the user to login.
            await sl<AuthLocalDataSource>().clearAll();
            return handler.next(error);
          }

          // Retry the original request once with the new token.
          final retryOptions = error.requestOptions
            ..headers[ApiConstants.authorizationHeader] = 'Bearer $newAccessToken'
            ..extra['_retried'] = true;

          try {
            final response = await dio.fetch(retryOptions);
            return handler.resolve(response);
          } catch (e) {
            return handler.next(e is DioException ? e : error);
          }
        },
      ),
    );

    // Add logging in debug mode
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
      ),
    );

    return dio;
  });

  // Flutter Secure Storage
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
    ),
  );

  // Shared Preferences (for macOS fallback)
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);

  // Internet Connection Checker (skip on web — dart:io not supported there)
  if (!kIsWeb) {
    sl.registerLazySingleton(() => InternetConnectionChecker());
  }
}
