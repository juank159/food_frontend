import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_statistics.dart';
import '../../domain/usecases/delete_customer_usecase.dart';
import '../../domain/usecases/get_customer_statistics_usecase.dart';
import '../../domain/usecases/get_customers_usecase.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Customers Controller
///
/// Maneja el listado, búsqueda, KPIs y acciones rápidas (toggle activo,
/// eliminar) sobre el módulo de clientes. La búsqueda se debouncia para
/// no martillar al backend mientras el usuario tipea.
class CustomersController extends GetxController {
  final GetCustomersUseCase getCustomersUseCase;
  final GetCustomerStatisticsUseCase getStatisticsUseCase;
  final DeleteCustomerUseCase deleteCustomerUseCase;

  CustomersController({
    required this.getCustomersUseCase,
    required this.getStatisticsUseCase,
    required this.deleteCustomerUseCase,
  });

  // Estado observable.
  final RxList<Customer> customers = <Customer>[].obs;
  final Rx<CustomerStatistics> statistics =
      CustomerStatistics.empty().obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingStats = false.obs;
  final RxString errorMessage = ''.obs;

  // Filtros.
  final RxString searchQuery = ''.obs;
  final RxBool showOnlyActive = false.obs;

  // Debounce para la búsqueda (evita un GET por cada tecla).
  Worker? _searchWorker;

  @override
  void onInit() {
    super.onInit();
    _searchWorker = debounce<String>(
      searchQuery,
      (_) => loadCustomers(),
      time: const Duration(milliseconds: 350),
    );
    loadCustomers();
    loadStatistics();
  }

  @override
  void onClose() {
    _searchWorker?.dispose();
    super.onClose();
  }

  /// Carga el listado aplicando los filtros activos.
  Future<void> loadCustomers() async {
    isLoading.value = true;
    errorMessage.value = '';

    final result = await getCustomersUseCase(
      isActive: showOnlyActive.value ? true : null,
      search: searchQuery.value.isEmpty ? null : searchQuery.value,
    );

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        isLoading.value = false;
      },
      (list) {
        customers.value = list;
        isLoading.value = false;
      },
    );
  }

  /// Carga las KPIs del header. Falla en silencio (chips muestran 0)
  /// para no bloquear la pantalla principal si stats no responde.
  Future<void> loadStatistics() async {
    isLoadingStats.value = true;
    final result = await getStatisticsUseCase();
    result.fold(
      (failure) {
        debugPrint('CustomersController: stats failed → ${failure.message}');
        isLoadingStats.value = false;
      },
      (stats) {
        statistics.value = stats;
        isLoadingStats.value = false;
      },
    );
  }

  Future<void> refreshAll() async {
    await Future.wait([loadCustomers(), loadStatistics()]);
  }

  void onSearchChanged(String value) {
    searchQuery.value = value.trim();
  }

  void clearSearch() {
    searchQuery.value = '';
  }

  void toggleActiveFilter() {
    showOnlyActive.value = !showOnlyActive.value;
    loadCustomers();
  }

  /// Elimina un cliente y refresca el listado en caso de éxito.
  Future<bool> deleteCustomer(String id) async {
    final result = await deleteCustomerUseCase(id);
    return result.fold(
      (failure) {
        AppSnackbar.show(
          'Error',
          failure.message,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
        );
        return false;
      },
      (_) async {
        await refreshAll();
        AppSnackbar.show(
          'Cliente eliminado',
          'El cliente fue eliminado correctamente',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
        );
        return true;
      },
    );
  }

  // Cómputos de KPIs sobre el listado actual (cuando el endpoint de stats
  // no llegó todavía, calculamos del listado para no mostrar "0").

  int get totalCount {
    final fromStats = statistics.value.totalCustomers;
    return fromStats > 0 ? fromStats : customers.length;
  }

  int get activeCount {
    final fromStats = statistics.value.activeCustomers;
    if (fromStats > 0) return fromStats;
    return customers.where((c) => c.isActive).length;
  }

  int get newThisMonthCount {
    return customers.where((c) => c.isNewThisMonth).length;
  }

  bool get hasCustomers => customers.isNotEmpty;
}
