import 'package:get/get.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../domain/entities/cash_session.dart';
import '../../domain/usecases/cash_session_usecases.dart';
import 'cash_session_guard.dart';

/// Controlador de la pantalla central de caja.
///
/// Maneja el estado de la sesión actual del cajero (open / closed /
/// none) y orquesta abrir/cerrar. Después de cualquier mutación,
/// recarga la sesión actual para que la UI vea los rollups actualizados.
class CashSessionController extends GetxController {
  final CashSessionUseCases useCases;

  CashSessionController({required this.useCases});

  /// Sesión activa del usuario (open). Null si no tiene caja abierta.
  final Rx<CashSession?> currentSession = Rx<CashSession?>(null);

  /// Última sesión cerrada (para mostrar el resumen post-cierre).
  /// Se setea solo después de cerrar; null en el flujo normal.
  final Rx<CashSession?> lastClosed = Rx<CashSession?>(null);

  final RxBool isLoading = false.obs;
  final RxBool isMutating = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadCurrent();
  }

  Future<void> loadCurrent() async {
    isLoading.value = true;
    errorMessage.value = '';
    final result = await useCases.getCurrent();
    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        currentSession.value = null;
      },
      (session) {
        currentSession.value = session;
      },
    );
    // Mantener guard global sincronizado.
    ensureCashGuardRegistered();
    if (currentSession.value != null && currentSession.value!.isOpen) {
      cashGuard().markOpened();
    } else {
      cashGuard().markClosed();
    }
    isLoading.value = false;
  }

  /// Abre una sesión nueva. Devuelve true si fue exitoso.
  Future<bool> open({
    required double openingAmount,
    String? notes,
  }) async {
    isMutating.value = true;
    final result = await useCases.open(
      openingAmount: openingAmount,
      notes: notes,
    );
    isMutating.value = false;
    return result.fold(
      (failure) {
        AppSnackbar.show('No se pudo abrir', failure.message);
        return false;
      },
      (session) {
        currentSession.value = session;
        lastClosed.value = null;
        ensureCashGuardRegistered();
        cashGuard().markOpened();
        AppSnackbar.show('Caja abierta', 'Ya podés empezar a cobrar');
        return true;
      },
    );
  }

  /// Cierra la sesión actual. Si la diferencia es grande y `force=false`,
  /// devuelve un Failure especial que la UI usa para pedir confirmación.
  Future<bool> close({
    required double closingAmountCounted,
    String? closingNotes,
    bool force = false,
  }) async {
    final s = currentSession.value;
    if (s == null) return false;
    isMutating.value = true;
    final result = await useCases.close(
      id: s.id,
      closingAmountCounted: closingAmountCounted,
      closingNotes: closingNotes,
      force: force,
    );
    isMutating.value = false;
    return result.fold(
      (failure) {
        // Cuando viene CASH_DIFFERENCE significa "confirma con force=true".
        // La UI captura este mensaje y muestra dialog de confirmación.
        AppSnackbar.show('Cierre rechazado', failure.message);
        return false;
      },
      (closed) {
        lastClosed.value = closed;
        currentSession.value = null;
        ensureCashGuardRegistered();
        cashGuard().markClosed();
        AppSnackbar.show('Caja cerrada', 'Resumen disponible');
        return true;
      },
    );
  }

  /// Recarga manualmente — pull-to-refresh.
  Future<void> reloadCurrent() => loadCurrent();

  /// Vuelve al estado "sin sesión" tras visualizar el resumen del cierre.
  void dismissLastClosed() {
    lastClosed.value = null;
  }
}
