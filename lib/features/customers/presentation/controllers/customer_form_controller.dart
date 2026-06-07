import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../domain/entities/customer.dart';
import '../../domain/usecases/create_customer_usecase.dart';
import '../../domain/usecases/update_customer_usecase.dart';
import './customers_controller.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Customer Form Controller
///
/// Crea o edita un cliente. El cliente a editar se inyecta vía
/// `Get.arguments` (igual patrón que `ProductFormController`) y el
/// binding lo recoge para setear `customerToEdit`.
class CustomerFormController extends GetxController {
  final CreateCustomerUseCase createCustomerUseCase;
  final UpdateCustomerUseCase updateCustomerUseCase;

  CustomerFormController({
    required this.createCustomerUseCase,
    required this.updateCustomerUseCase,
  });

  final formKey = GlobalKey<FormState>();

  // Cliente a editar (null = modo creación).
  Customer? customerToEdit;
  bool get isEditMode => customerToEdit != null;

  // Estado.
  final RxBool isSaving = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isActive = true.obs;

  // Controllers de los campos.
  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController emailController;
  late final TextEditingController notesController;

  @override
  void onInit() {
    super.onInit();
    nameController = TextEditingController();
    phoneController = TextEditingController();
    emailController = TextEditingController();
    notesController = TextEditingController();

    // Si vino un Customer en arguments y el binding no lo seteó,
    // lo levantamos acá. Soporta dos rutas de inyección.
    if (customerToEdit == null && Get.arguments is Customer) {
      customerToEdit = Get.arguments as Customer;
    }

    if (customerToEdit != null) {
      _hydrateFromCustomer(customerToEdit!);
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    notesController.dispose();
    super.onClose();
  }

  void _hydrateFromCustomer(Customer customer) {
    nameController.text = customer.fullName;
    phoneController.text = customer.phone;
    emailController.text = customer.email ?? '';
    notesController.text = customer.notes ?? '';
    isActive.value = customer.isActive;
  }

  bool _validate() {
    errorMessage.value = '';
    final state = formKey.currentState;
    if (state == null || !state.validate()) {
      errorMessage.value = 'Por favor completá los campos requeridos';
      return false;
    }
    return true;
  }

  Future<void> saveCustomer() async {
    if (!_validate()) {
      AppSnackbar.show(
        'Validación',
        errorMessage.value,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return;
    }

    isSaving.value = true;
    errorMessage.value = '';

    try {
      if (isEditMode) {
        await _updateCustomer();
      } else {
        await _createCustomer();
      }
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _createCustomer() async {
    final result = await createCustomerUseCase(
      fullName: nameController.text.trim(),
      phone: phoneController.text.trim(),
      email: _emptyToNull(emailController.text),
      notes: _emptyToNull(notesController.text),
      isActive: isActive.value,
    );

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        AppSnackbar.show(
          'Error',
          failure.message,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
          duration: const Duration(seconds: 5),
        );
      },
      (customer) {
        AppSnackbar.show(
          'Cliente creado',
          '${customer.fullName} fue agregado correctamente',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
        );
        _refreshListIfRegistered();
        Get.back<Customer>(result: customer);
      },
    );
  }

  Future<void> _updateCustomer() async {
    final result = await updateCustomerUseCase(
      id: customerToEdit!.id,
      fullName: nameController.text.trim(),
      phone: phoneController.text.trim(),
      email: _emptyToNull(emailController.text),
      notes: _emptyToNull(notesController.text),
      isActive: isActive.value,
    );

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        AppSnackbar.show(
          'Error',
          failure.message,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
          duration: const Duration(seconds: 5),
        );
      },
      (customer) {
        AppSnackbar.show(
          'Cliente actualizado',
          '${customer.fullName} fue actualizado correctamente',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
        );
        _refreshListIfRegistered();
        Get.back<Customer>(result: customer);
      },
    );
  }

  void _refreshListIfRegistered() {
    // Si la lista está montada (caso típico: form abierto desde la lista),
    // refrescamos. Si no, lo ignoramos.
    if (Get.isRegistered<CustomersController>()) {
      Get.find<CustomersController>().refreshAll();
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
