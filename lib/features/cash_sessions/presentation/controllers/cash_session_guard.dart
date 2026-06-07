import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/cash_session_usecases.dart';

/// Guardia global de estado de caja.
///
/// **Por qué un controller separado del `CashSessionController`:**
/// - El otro controller maneja la pantalla `/cash-register` (loadCurrent,
///   open, close, lastClosed). Se crea/destruye con esa ruta.
/// - Este guardia tiene que vivir SIEMPRE para que cualquier pantalla
///   de cobro pueda saber al instante si hay caja abierta sin armar su
///   propia query. Se registra como `permanent` en el container.
///
/// **Reactivo:** los widgets de cobro hacen `Obx(() => guard.hasOpen.value)`
/// y se actualizan automáticamente cuando se abre/cierra caja desde
/// cualquier parte de la app.
///
/// **Estados:**
/// - `null` → aún no verificado (loading inicial).
/// - `true` → hay sesión OPEN.
/// - `false` → no hay sesión.
class CashSessionGuardController extends GetxController {
  final CashSessionUseCases useCases;

  CashSessionGuardController({required this.useCases});

  final Rxn<bool> hasOpen = Rxn<bool>();
  final RxBool isChecking = false.obs;

  @override
  void onInit() {
    super.onInit();
    refreshState();
  }

  /// Re-consulta el backend y actualiza `hasOpen`. Se llama:
  /// - Al iniciar la app (onInit).
  /// - Después de abrir/cerrar caja (manual desde el caller).
  /// - Cuando un widget de cobro entra a pantalla con cash seleccionado.
  Future<void> refreshState() async {
    if (isChecking.value) return;
    isChecking.value = true;
    final result = await useCases.getCurrent();
    result.fold(
      (_) {
        // Error de red — no cambiamos el último estado conocido.
        // El backend igual valida en server-side; acá no bloqueamos
        // por fallos transitorios.
      },
      (session) {
        hasOpen.value = session != null && session.isOpen;
      },
    );
    isChecking.value = false;
  }

  /// Marca que se acaba de abrir caja sin esperar al fetch.
  /// Llamado desde el dialog de apertura tras éxito — UX instantánea.
  void markOpened() {
    hasOpen.value = true;
  }

  /// Marca que se acaba de cerrar — para que cualquier pantalla de
  /// cobro abierta vea el cambio al instante.
  void markClosed() {
    hasOpen.value = false;
  }
}

/// Acceso rápido al guardia desde cualquier widget.
/// Asume que el controller está registrado (lo hacemos en
/// `injection_container.init`).
CashSessionGuardController cashGuard() =>
    Get.find<CashSessionGuardController>();

/// Auto-registro del controller si no está vivo todavía — útil para
/// pantallas que pueden cargarse antes que la init principal complete.
void ensureCashGuardRegistered() {
  if (!Get.isRegistered<CashSessionGuardController>()) {
    Get.put<CashSessionGuardController>(
      CashSessionGuardController(useCases: sl<CashSessionUseCases>()),
      permanent: true,
    );
  }
}
