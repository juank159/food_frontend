import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/cash_session_usecases.dart';
import '../controllers/cash_session_controller.dart';
import '../controllers/cash_session_guard.dart';
import 'open_cash_dialog.dart';

/// Banner inline que aparece dentro del flujo de cobro cuando:
///   - El método de pago seleccionado es `cash`.
///   - El cajero NO tiene una sesión de caja OPEN.
///
/// **Reactivo:** se subscribe al `CashSessionGuardController` global,
/// así si el cajero abre/cierra caja desde otra ventana o navegación,
/// el banner se actualiza al instante sin un nuevo fetch.
///
/// Devuelve `SizedBox.shrink()` cuando no hace falta mostrar el banner
/// (método no-cash o caja ya abierta).
class CashSessionRequiredBanner extends StatefulWidget {
  final bool isCashSelected;

  /// Callback opcional cuando el cajero abre caja desde el banner —
  /// el padre puede usarlo para refrescar su estado/validación.
  final VoidCallback? onSessionOpened;

  const CashSessionRequiredBanner({
    super.key,
    required this.isCashSelected,
    this.onSessionOpened,
  });

  @override
  State<CashSessionRequiredBanner> createState() =>
      _CashSessionRequiredBannerState();
}

class _CashSessionRequiredBannerState
    extends State<CashSessionRequiredBanner> {
  @override
  void initState() {
    super.initState();
    ensureCashGuardRegistered();
    // Refrescamos al entrar — por si la caja se abrió/cerró en otra
    // pantalla mientras este widget no existía.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) cashGuard().refreshState();
    });
  }

  Future<void> _onOpenCash() async {
    // OpenCashDialog usa CashSessionController. Lo registramos
    // on-demand si no estamos viniendo desde /cash-register.
    if (!Get.isRegistered<CashSessionController>()) {
      Get.put<CashSessionController>(
        CashSessionController(useCases: sl<CashSessionUseCases>()),
      );
    }
    final opened = await Get.dialog<bool>(
      const OpenCashDialog(),
      barrierDismissible: false,
    );
    if (opened == true) {
      // El controller de la pantalla de caja ya actualizó su estado.
      // Sincronizamos el guard global para que TODOS los widgets de
      // cobro abiertos vean la caja como activa al instante.
      cashGuard().markOpened();
      widget.onSessionOpened?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCashSelected) return const SizedBox.shrink();

    return Obx(() {
      final guard = cashGuard();
      final state = guard.hasOpen.value;

      // Caja confirmada abierta → no mostramos nada.
      if (state == true) return const SizedBox.shrink();

      // Estado desconocido (loading inicial) → loader sutil.
      // Bloqueamos visualmente para que el cajero no le dé "Procesar"
      // antes de saber el estado real (el botón también está disabled
      // vía `paymentCanSubmit`).
      if (state == null) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text(
                'Verificando estado de caja…',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }

      // Caja cerrada confirmado → banner bloqueante.
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.4),
            width: 1.4,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No tenés caja abierta',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.warning,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Para cobrar en efectivo necesitás abrir caja primero. Lo podés hacer sin perder este cobro.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _onOpenCash,
                icon: const Icon(Icons.point_of_sale, size: 16),
                label: const Text(
                  'Abrir caja ahora',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Helper para que cualquier widget de cobro pueda saber si el botón
/// "Procesar pago" debe estar habilitado considerando el método elegido.
///
/// Reglas:
/// - Método no-cash → siempre permitido.
/// - Método cash + caja abierta (`hasOpen=true`) → permitido.
/// - Método cash + caja cerrada (`hasOpen=false`) → bloqueado.
/// - Método cash + estado desconocido (`null`, loading inicial) →
///   bloqueado (mejor pecar de cauteloso que dejar pasar un cobro
///   que el backend va a rechazar).
///
/// Para usar dentro de un `Obx`:
/// ```dart
/// Obx(() => FilledButton(
///   onPressed: canSubmitWithCashGuard(method == cash)
///       ? _processPayment
///       : null,
///   ...
/// ))
/// ```
bool canSubmitWithCashGuard(bool isCashSelected) {
  if (!isCashSelected) return true;
  ensureCashGuardRegistered();
  return cashGuard().hasOpen.value == true;
}
