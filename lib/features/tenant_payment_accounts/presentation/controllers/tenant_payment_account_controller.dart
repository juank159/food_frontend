import 'package:get/get.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../domain/entities/tenant_payment_account.dart';
import '../../domain/usecases/tenant_payment_account_usecases.dart';

/// Controlador del CRUD de cuentas de pago del tenant.
///
/// Mantiene `accounts` agrupados por categoría para la UI. Reusamos
/// `AppSnackbar` para alinear con el resto del proyecto.
class TenantPaymentAccountController extends GetxController {
  final TenantPaymentAccountUseCases useCases;

  TenantPaymentAccountController({required this.useCases});

  final RxList<TenantPaymentAccount> accounts = <TenantPaymentAccount>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadAccounts();
  }

  Map<PaymentMethod, List<TenantPaymentAccount>> get accountsByCategory {
    final map = <PaymentMethod, List<TenantPaymentAccount>>{};
    for (final account in accounts) {
      map.putIfAbsent(account.category, () => []).add(account);
    }
    return map;
  }

  Future<void> loadAccounts({PaymentMethod? category, bool? onlyActive}) async {
    isLoading.value = true;
    errorMessage.value = '';
    final result = await useCases.getAll(
      category: category,
      onlyActive: onlyActive,
    );
    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        AppSnackbar.show('Error', failure.message);
      },
      (list) => accounts.assignAll(list),
    );
    isLoading.value = false;
  }

  Future<bool> createAccount({
    required String name,
    required PaymentMethod category,
    String? accountNumber,
    String? accountHolder,
    String? icon,
    String? notes,
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    isSaving.value = true;
    final result = await useCases.create(
      name: name,
      category: category,
      accountNumber: accountNumber,
      accountHolder: accountHolder,
      icon: icon,
      notes: notes,
      isActive: isActive,
      sortOrder: sortOrder,
    );
    isSaving.value = false;
    return result.fold(
      (failure) {
        AppSnackbar.show('Error', failure.message);
        return false;
      },
      (account) {
        accounts.add(account);
        AppSnackbar.show('Listo', 'Cuenta "${account.name}" creada');
        return true;
      },
    );
  }

  Future<bool> updateAccount({
    required String id,
    String? name,
    PaymentMethod? category,
    String? accountNumber,
    String? accountHolder,
    String? icon,
    String? notes,
    bool? isActive,
    int? sortOrder,
  }) async {
    isSaving.value = true;
    final result = await useCases.update(
      id: id,
      name: name,
      category: category,
      accountNumber: accountNumber,
      accountHolder: accountHolder,
      icon: icon,
      notes: notes,
      isActive: isActive,
      sortOrder: sortOrder,
    );
    isSaving.value = false;
    return result.fold(
      (failure) {
        AppSnackbar.show('Error', failure.message);
        return false;
      },
      (account) {
        final index = accounts.indexWhere((a) => a.id == id);
        if (index >= 0) accounts[index] = account;
        AppSnackbar.show('Listo', 'Cuenta actualizada');
        return true;
      },
    );
  }

  Future<void> toggleActive(TenantPaymentAccount account) async {
    final result = await useCases.toggleActive(account.id);
    result.fold(
      (failure) => AppSnackbar.show('Error', failure.message),
      (updated) {
        final index = accounts.indexWhere((a) => a.id == updated.id);
        if (index >= 0) accounts[index] = updated;
      },
    );
  }

  Future<bool> deleteAccount(String id) async {
    final result = await useCases.delete(id);
    return result.fold(
      (failure) {
        AppSnackbar.show('Error', failure.message);
        return false;
      },
      (_) {
        accounts.removeWhere((a) => a.id == id);
        AppSnackbar.show('Listo', 'Cuenta eliminada');
        return true;
      },
    );
  }
}
