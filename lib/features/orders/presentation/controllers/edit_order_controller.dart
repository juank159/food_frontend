import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../domain/entities/order.dart';
import '../../domain/usecases/get_order_by_id_usecase.dart';
import '../../domain/usecases/update_order_usecase.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Controller para la edición de metadata de una orden existente.
///
/// Limitación de scope: este flujo edita solo metadata (instrucciones,
/// mesa, cliente, dirección, ETA). No permite tocar items/modifiers —
/// para eso se necesita un endpoint backend `replaceItems` que aún no
/// existe (TODO en backlog).
class EditOrderController extends GetxController {
  final GetOrderByIdUseCase getOrderByIdUseCase;
  final UpdateOrderUseCase updateOrderUseCase;

  EditOrderController({
    required this.getOrderByIdUseCase,
    required this.updateOrderUseCase,
  });

  // Form
  final formKey = GlobalKey<FormState>();
  late final TextEditingController specialInstructionsController;
  late final TextEditingController estimatedTimeController;
  late final TextEditingController customerNameController;

  // State
  final Rx<Order?> order = Rx<Order?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxString errorMessage = ''.obs;

  String? _orderId;

  @override
  void onInit() {
    super.onInit();
    specialInstructionsController = TextEditingController();
    estimatedTimeController = TextEditingController();
    customerNameController = TextEditingController();

    _orderId = Get.parameters['id'];
    final cached = Get.arguments;
    if (cached is Order) {
      order.value = cached;
      _orderId ??= cached.id;
      _hydrateFromOrder(cached);
    }
    if (_orderId != null) load();
  }

  @override
  void onClose() {
    specialInstructionsController.dispose();
    estimatedTimeController.dispose();
    customerNameController.dispose();
    super.onClose();
  }

  void _hydrateFromOrder(Order o) {
    specialInstructionsController.text = o.specialInstructions ?? '';
    estimatedTimeController.text = (o.estimatedTime ?? 0) > 0
        ? o.estimatedTime!.toString()
        : '';
    customerNameController.text = o.customerName ?? '';
  }

  Future<void> load() async {
    if (_orderId == null) {
      errorMessage.value = 'ID de orden inválido';
      return;
    }
    isLoading.value = true;
    errorMessage.value = '';
    final result = await getOrderByIdUseCase(_orderId!);
    result.fold(
      (failure) => errorMessage.value = failure.message,
      (loaded) {
        order.value = loaded;
        _hydrateFromOrder(loaded);
      },
    );
    isLoading.value = false;
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (_orderId == null) return;

    isSaving.value = true;
    errorMessage.value = '';

    final etaText = estimatedTimeController.text.trim();
    final eta = etaText.isEmpty ? null : int.tryParse(etaText);

    final result = await updateOrderUseCase(
      id: _orderId!,
      specialInstructions: specialInstructionsController.text.trim(),
      estimatedTime: eta,
      customerName: customerNameController.text.trim().isEmpty
          ? null
          : customerNameController.text.trim(),
    );

    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        AppSnackbar.show(
          'Error',
          failure.message,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 4),
        );
      },
      (updated) {
        order.value = updated;
        Get.back<Order>(result: updated);
        AppSnackbar.show(
          'Orden actualizada',
          'Los cambios fueron guardados',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 3),
        );
      },
    );

    isSaving.value = false;
  }
}
