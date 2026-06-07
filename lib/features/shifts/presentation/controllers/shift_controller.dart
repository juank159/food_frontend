import 'package:get/get.dart';

import '../../../../core/utils/app_snackbar.dart';
import '../../domain/entities/shift.dart';
import '../../domain/usecases/shift_usecases.dart';

/// Controlador de la pantalla de turnos.
///
/// Maneja el turno actual del usuario logueado (clock-in/clock-out) y
/// el histórico. El estado activo de turno se expone para que otros
/// widgets (ej: card en home) puedan reactivos.
class ShiftController extends GetxController {
  final ShiftUseCases useCases;

  ShiftController({required this.useCases});

  final Rx<Shift?> currentShift = Rx<Shift?>(null);
  final RxList<Shift> history = <Shift>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isMutating = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadCurrent();
  }

  /// Refresca el turno actual desde backend.
  Future<void> loadCurrent() async {
    isLoading.value = true;
    errorMessage.value = '';
    final result = await useCases.getMyCurrent();
    result.fold(
      (f) {
        errorMessage.value = f.message;
      },
      (s) {
        currentShift.value = s;
      },
    );
    isLoading.value = false;
  }

  /// Carga el histórico (default: últimos 20).
  Future<void> loadHistory({int limit = 20}) async {
    final result = await useCases.getMine(limit: limit);
    result.fold(
      (f) => errorMessage.value = f.message,
      (list) => history.assignAll(list),
    );
  }

  /// Marca entrada. Devuelve true si fue exitoso.
  Future<bool> clockIn({String? notes}) async {
    if (isMutating.value) return false;
    isMutating.value = true;
    final result = await useCases.clockIn(notes: notes);
    isMutating.value = false;
    return result.fold(
      (f) {
        AppSnackbar.show('No se pudo marcar entrada', f.message);
        return false;
      },
      (s) {
        currentShift.value = s;
        AppSnackbar.show('Entrada marcada', 'Buen turno 👋');
        return true;
      },
    );
  }

  /// Cierra el turno actual. Devuelve true si fue exitoso.
  Future<bool> clockOut({String? notes}) async {
    if (isMutating.value) return false;
    if (currentShift.value == null) return false;
    isMutating.value = true;
    final result = await useCases.clockOut(notes: notes);
    isMutating.value = false;
    return result.fold(
      (f) {
        AppSnackbar.show('No se pudo cerrar turno', f.message);
        return false;
      },
      (closed) {
        // Lo movemos al histórico (top) y limpiamos el actual.
        history.insert(0, closed);
        currentShift.value = null;
        AppSnackbar.show(
          'Turno cerrado',
          'Trabajaste ${closed.formattedDuration}',
        );
        return true;
      },
    );
  }
}
