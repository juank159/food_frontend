// lib features/tab_sessions/presentation/controllers/tab_session_detail_controller.dart
import 'package:get/get.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../domain/entities/tab_session.dart';
import '../../domain/usecases/tab_session_usecases.dart';

/// Controla la pantalla de detalle de una cuenta abierta.
///
/// Responsabilidades:
/// - Cargar la sesión con tickets y pagos.
/// - Refrescar después de acciones (agregar ticket, pagar, cerrar).
/// - Cerrar / anular la cuenta.
class TabSessionDetailController extends GetxController {
  final TabSessionUseCases useCases;

  TabSessionDetailController({required this.useCases});

  final Rx<TabSession?> session = Rx<TabSession?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isMutating = false.obs;
  final RxString errorMessage = ''.obs;

  String? _sessionId;

  Future<void> init(String sessionId) async {
    _sessionId = sessionId;
    await load();
  }

  Future<void> load() async {
    if (_sessionId == null) return;
    isLoading.value = true;
    errorMessage.value = '';
    final result = await useCases.findOne(_sessionId!);
    result.fold((failure) {
      errorMessage.value = failure.message;
      AppSnackbar.show('Error', failure.message);
    }, (s) => session.value = s);
    isLoading.value = false;
  }

  Future<bool> close({bool force = false, String? notes}) async {
    if (_sessionId == null) return false;
    isMutating.value = true;
    final result = await useCases.close(
      id: _sessionId!,
      force: force,
      notes: notes,
    );
    isMutating.value = false;
    return result.fold(
      (failure) {
        AppSnackbar.show('Error', failure.message);
        return false;
      },
      (updated) {
        session.value = updated;
        AppSnackbar.show('Listo', 'Cuenta cerrada');
        return true;
      },
    );
  }

  Future<bool> updateCustomerName(String name) async {
    if (_sessionId == null) return false;
    isMutating.value = true;
    final result = await useCases.update(
      _sessionId!,
      customerName: name.trim().isEmpty ? '' : name.trim(),
    );
    isMutating.value = false;
    return result.fold(
      (failure) {
        AppSnackbar.show('Error', failure.message);
        return false;
      },
      (updated) {
        session.value = updated;
        session.refresh(); // fuerza Obx aunque Equatable diga equal
        return true;
      },
    );
  }

  Future<bool> updateNotes(String notes) async {
    if (_sessionId == null) return false;
    isMutating.value = true;
    final result = await useCases.update(
      _sessionId!,
      notes: notes.trim(),
    );
    isMutating.value = false;
    return result.fold(
      (failure) {
        AppSnackbar.show('Error', failure.message);
        return false;
      },
      (updated) {
        session.value = updated;
        session.refresh(); // fuerza Obx aunque Equatable diga equal
        return true;
      },
    );
  }

  Future<bool> voidSession() async {
    if (_sessionId == null) return false;
    isMutating.value = true;
    final result = await useCases.voidSession(_sessionId!);
    isMutating.value = false;
    return result.fold(
      (failure) {
        AppSnackbar.show('Error', failure.message);
        return false;
      },
      (_) {
        AppSnackbar.show('Listo', 'Cuenta anulada');
        return true;
      },
    );
  }
}
