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
    if (session.value?.id != sessionId) session.value = null;
    await load();
  }

  /// Bug real reportado (optimización pedida): esta pantalla SIEMPRE
  /// esperaba a la red para pintar algo — a diferencia del listado de
  /// "Cuentas abiertas" (`OpenTabsController.load`), que ya pinta
  /// desde caché al instante y la red reemplaza atrás. Esa misma
  /// caché (la lista de cuentas abiertas) YA trae las `orders` de cada
  /// sesión — no tan completas como `findOne` (sin items/payments
  /// anidados), pero de sobra para el primer pintado (totales,
  /// cliente, cantidad de tickets). Reusamos esa caché en vez de crear
  /// una nueva por-detalle.
  ///
  /// Bug real reportado: la lista liviana no trae los `payments` de cada
  /// ticket, así que el primer pintado mostraba "Debe $X" en tickets ya
  /// pagados. Ahora se prefiere la copia COMPLETA de esta cuenta
  /// (`peekCachedSessionDetail`), y solo se pinta desde caché si la
  /// pantalla está vacía — un refresco (tiempo real, volver de cobrar)
  /// no vuelve a pisar datos buenos con una copia vieja.
  Future<void> load() async {
    if (_sessionId == null) return;

    if (session.value == null) {
      final cached = await useCases.peekCachedSessionDetail(_sessionId!);
      if (cached != null) session.value = cached;
    }
    final paintedFromCache = session.value != null;

    isLoading.value = !paintedFromCache;
    errorMessage.value = '';
    final result = await useCases.findOne(_sessionId!);
    result.fold((failure) {
      // Si ya había algo pintado desde caché, no molestamos con un
      // error — mismo criterio que `OpenTabsController.load`.
      if (paintedFromCache) return;
      errorMessage.value = failure.message;
      AppSnackbar.show('Error', failure.message);
    }, (s) {
      // Bug real reportado: cuenta pagada (saldo $0) pero la card del
      // ticket seguía en "Debe $X". La caché de arriba no trae los
      // `payments` de cada ticket, y `TabSession` no compara `orders`
      // en su `==` — con los mismos totales, GetX ve el valor de red
      // "igual" al de caché y DESCARTA la asignación (`Rx.value` no
      // asigna si `==`), así que quedaban los tickets sin pagos. Se
      // suelta el de caché primero para que el de red sí entre.
      if (session.value == s) session.value = null;
      session.value = s;
    });
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
    final result = await useCases.update(_sessionId!, notes: notes.trim());
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
