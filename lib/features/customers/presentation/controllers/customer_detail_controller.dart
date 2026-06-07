import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../features/orders/domain/entities/order.dart' as order_entity;
import '../../../../features/orders/domain/usecases/get_orders_usecase.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_address.dart';
import '../../domain/repositories/customer_repository.dart';
import '../../domain/usecases/get_customer_by_id_usecase.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Estado de carga de la pantalla de detalle.
///
/// Lo modelamos como enum para que la UI pueda hacer `switch` exhaustivo
/// y el resto de los flags (loading addresses, loading orders, etc.) no se
/// crucen — el "estado principal" de la pantalla es uno solo.
enum CustomerDetailStatus { loading, loaded, error }

/// Controlador de la pantalla de detalle de cliente.
///
/// Carga en paralelo:
///   - el cliente (`GET /customers/:id`)
///   - sus addresses (`GET /customers/:id/addresses`)
///   - sus últimas órdenes (`GET /orders?customer_id=:id`)
///
/// Si falla el principal (cliente) la pantalla queda en estado de error.
/// Si fallan los secundarios (addresses / órdenes) la pantalla se sigue
/// mostrando con su sección vacía — son nice-to-haves, no bloquean.
class CustomerDetailController extends GetxController {
  final GetCustomerByIdUseCase getCustomerByIdUseCase;
  final GetOrdersUseCase getOrdersUseCase;
  // El repo se inyecta directo porque no hay use cases dedicados para
  // addresses (mismo patrón que el form usa con `CustomerRepository`).
  final CustomerRepository customerRepository;

  CustomerDetailController({
    required this.getCustomerByIdUseCase,
    required this.getOrdersUseCase,
    required this.customerRepository,
  });

  // ─────────────────────────── Estado principal ───────────────────────────

  final Rx<CustomerDetailStatus> status =
      CustomerDetailStatus.loading.obs;
  final RxString errorMessage = ''.obs;

  final Rxn<Customer> customer = Rxn<Customer>();

  // Addresses — cargados aparte del cliente porque el endpoint dedicado da
  // la lista actualizada (el endpoint /:id puede no traerlas embebidas).
  final RxList<CustomerAddress> addresses = <CustomerAddress>[].obs;
  final RxBool isLoadingAddresses = false.obs;

  // Última actividad: top 10 órdenes del cliente.
  final RxList<order_entity.Order> recentOrders =
      <order_entity.Order>[].obs;
  final RxBool isLoadingOrders = false.obs;

  /// El ID se inyecta vía `Get.parameters['id']` en `onInit`.
  String? customerId;

  @override
  void onInit() {
    super.onInit();
    customerId = Get.parameters['id'];
    if (customerId == null || customerId!.isEmpty) {
      status.value = CustomerDetailStatus.error;
      errorMessage.value = 'No se pudo identificar el cliente';
      return;
    }
    loadAll();
  }

  // ─────────────────────────── Carga ───────────────────────────

  Future<void> loadAll() async {
    if (customerId == null) return;
    status.value = CustomerDetailStatus.loading;
    errorMessage.value = '';

    final customerResult = await getCustomerByIdUseCase(customerId!);
    customerResult.fold(
      (failure) {
        status.value = CustomerDetailStatus.error;
        errorMessage.value = failure.message;
      },
      (loaded) {
        customer.value = loaded;
        // Si el cliente trae addresses embebidas, las usamos como cache
        // mientras dispara el GET dedicado.
        if (loaded.addresses.isNotEmpty) {
          addresses.assignAll(loaded.addresses);
        }
        status.value = CustomerDetailStatus.loaded;
      },
    );

    if (status.value == CustomerDetailStatus.loaded) {
      // Addresses y órdenes corren en paralelo para cortar latencia.
      await Future.wait([loadAddresses(), loadRecentOrders()]);
    }
  }

  Future<void> refreshAll() => loadAll();

  Future<void> loadAddresses() async {
    if (customerId == null) return;
    isLoadingAddresses.value = true;
    final result = await customerRepository.getAddresses(customerId!);
    result.fold(
      (failure) {
        // Silencioso: la sección queda vacía pero la pantalla no rompe.
        debugPrint(
          'CustomerDetailController: addresses failed → ${failure.message}',
        );
      },
      (list) => addresses.assignAll(list),
    );
    isLoadingAddresses.value = false;
  }

  Future<void> loadRecentOrders() async {
    if (customerId == null) return;
    isLoadingOrders.value = true;
    final result = await getOrdersUseCase(
      customerId: customerId,
      limit: 10,
    );
    result.fold(
      (failure) {
        debugPrint(
          'CustomerDetailController: orders failed → ${failure.message}',
        );
      },
      (list) {
        // El backend no garantiza orden por createdAt — ordenamos client-side
        // para que la "última orden" sea siempre la primera de la lista.
        final sorted = [...list]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        recentOrders.assignAll(sorted);
      },
    );
    isLoadingOrders.value = false;
  }

  // ─────────────────────────── Mutaciones de address ───────────────────────────

  /// Crea una nueva address para el cliente actual y refresca la sección.
  /// Devuelve `true` si se creó correctamente — la UI usa esto para cerrar
  /// el bottom sheet sólo cuando el guardado fue exitoso.
  Future<bool> createAddress({
    required String label,
    required String addressLine1,
    String? addressLine2,
    required String city,
    String? state,
    String? postalCode,
    String? deliveryInstructions,
    bool isDefault = false,
  }) async {
    if (customerId == null) return false;
    final result = await customerRepository.createAddress(
      customerId: customerId!,
      label: label,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      city: city,
      state: state,
      postalCode: postalCode,
      deliveryInstructions: deliveryInstructions,
      isDefault: isDefault,
    );
    return result.fold(
      (failure) {
        AppSnackbar.show(
          'Error',
          failure.message,
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.error,
          colorText: Colors.white,
        );
        return false;
      },
      (_) async {
        await loadAddresses();
        AppSnackbar.show(
          'Dirección agregada',
          'La dirección se guardó correctamente',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.success,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
        return true;
      },
    );
  }

  // ─────────────────────────── Derivados ───────────────────────────

  /// `true` mientras la página inicial carga el principal.
  bool get isLoading => status.value == CustomerDetailStatus.loading;
  bool get hasError => status.value == CustomerDetailStatus.error;
  bool get isLoaded => status.value == CustomerDetailStatus.loaded;

  CustomerAddress? get defaultAddress {
    if (addresses.isEmpty) return null;
    return addresses.firstWhereOrNull((a) => a.isDefault) ?? addresses.first;
  }
}
