import 'package:get/get.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../domain/entities/tab_session.dart';
import '../../domain/usecases/tab_session_usecases.dart';

/// Lista de cuentas abiertas (mesas + delivery activos).
///
/// Vista principal del POS para ver "qué mesas tengo trabajando" y
/// "cuánto debe cada una". Refresh automático: cada 20s para que no
/// haya que pull-down cada vez.
class OpenTabsController extends GetxController {
  final TabSessionUseCases useCases;

  OpenTabsController({required this.useCases});

  final RxList<TabSession> sessions = <TabSession>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isOpening = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = '';
    final result = await useCases.findOpen();
    result.fold(
      (failure) {
        errorMessage.value = failure.message;
        AppSnackbar.show('Error', failure.message);
      },
      (list) => sessions.assignAll(list),
    );
    isLoading.value = false;
  }

  /// Abre una cuenta "libre" — sin mesa del floor plan. Útil para
  /// clientes que se sentaron en sillas no registradas (zona verde,
  /// césped, terraza informal). La etiqueta queda en `notes` y se
  /// muestra como título de la card.
  ///
  /// Retorna el ID de la sesión creada, o null si falló.
  Future<String?> openFreeAccount({
    required String label,
    int? partySize,
  }) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      AppSnackbar.show('Etiqueta requerida',
          'Poné algo como "Césped #3" para identificar la cuenta.');
      return null;
    }
    isOpening.value = true;
    final result = await useCases.open(
      notes: trimmed,
      partySize: partySize,
    );
    isOpening.value = false;
    return result.fold(
      (failure) {
        AppSnackbar.show('No se pudo abrir', failure.message);
        return null;
      },
      (session) {
        sessions.insert(0, session);
        return session.id;
      },
    );
  }

  /// Suma de saldos pendientes de todas las cuentas — muestra en el
  /// header como "Pendiente total: $X".
  double get totalPendingBalance =>
      sessions.fold(0.0, (sum, s) => sum + s.balance);

  /// Cantidad total de tickets sumados de todas las cuentas.
  int get totalTickets =>
      sessions.fold(0, (sum, s) => sum + s.totalOrders);
}
