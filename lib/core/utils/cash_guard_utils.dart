import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../features/cash_sessions/domain/usecases/cash_session_usecases.dart';
import '../../features/cash_sessions/presentation/controllers/cash_session_controller.dart';
import '../../features/cash_sessions/presentation/controllers/cash_session_guard.dart';
import '../../features/cash_sessions/presentation/widgets/open_cash_dialog.dart';
import '../config/theme/app_colors.dart';
import '../di/injection_container.dart';

/// Registra el CashSessionController on-demand.
/// OpenCashDialog tiene un Obx que lee isMutating del controller; si
/// el controller no existe al montar el Obx, GetX lanza el error
/// "improper use of GetX" porque no hay ninguna variable reactiva leída.
void _ensureCashControllerRegistered() {
  if (!Get.isRegistered<CashSessionController>()) {
    Get.put<CashSessionController>(
      CashSessionController(useCases: sl<CashSessionUseCases>()),
    );
  }
}

/// Verifica que haya una caja abierta antes de proceder al cobro.
///
/// Flujo:
/// 1. Si el estado aún es desconocido (null) → espera un refresh.
/// 2. Si hay caja abierta:
///    - Verifica si es de un día anterior → muestra aviso (no bloqueante)
///      con opción de ir a cerrar o continuar de todas formas.
///    - Retorna `true` para proceder.
/// 3. Si no hay caja → muestra `OpenCashDialog` bloqueante.
///    - Si el cajero la abre → retorna `true`.
///    - Si cancela → retorna `false` (no se procede al cobro).
///
/// Usar en los puntos de entrada al pago:
/// ```dart
/// if (!await ensureOpenCash(context)) return;
/// // ... mostrar dialog de pago
/// ```
Future<bool> ensureOpenCash(BuildContext context) async {
  ensureCashGuardRegistered();
  final guard = cashGuard();

  // Esperar estado inicial si todavía no lo conocemos.
  if (guard.hasOpen.value == null) {
    await guard.refreshState();
  }

  if (guard.hasOpen.value == true) {
    // Verificar si la caja es del día anterior (aviso no bloqueante).
    final session = guard.currentSession.value;
    if (session != null && session.isFromPreviousDay && context.mounted) {
      await _showStaleCashWarning(context, session.openedAt);
    }
    return true;
  }

  // No hay caja abierta → mostrar diálogo para abrir.
  if (!context.mounted) return false;
  // Pre-registrar el controller: OpenCashDialog tiene un Obx que lo necesita
  // al montar; si no existe GetX falla con "improper use of GetX".
  _ensureCashControllerRegistered();
  final opened = await Get.dialog<bool>(
    const _NoCashDialog(),
    barrierDismissible: false,
  );
  return opened == true;
}

/// Dialog que aparece cuando no hay caja abierta al intentar cobrar.
/// Ofrece "Abrir caja ahora" o "Cancelar".
/// Si el cajero abre exitosamente, el dialog hace pop con `true`.
class _NoCashDialog extends StatefulWidget {
  const _NoCashDialog();

  @override
  State<_NoCashDialog> createState() => _NoCashDialogState();
}

class _NoCashDialogState extends State<_NoCashDialog> {
  bool _opening = false;

  Future<void> _onOpenCash() async {
    setState(() => _opening = true);
    // OpenCashDialog.Obx lee CashSessionController.isMutating al montar.
    // Si el controller no existe en ese momento, GetX falla con
    // "improper use of GetX". Lo registramos antes de abrir el dialog.
    _ensureCashControllerRegistered();
    final ok = await Get.dialog<bool>(
      const OpenCashDialog(),
      barrierDismissible: false,
    );
    if (!mounted) return;
    setState(() => _opening = false);
    if (ok == true) {
      cashGuard().markOpened();
      Navigator.of(context).pop(true); // ← comunica éxito al caller
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.point_of_sale_outlined,
                color: AppColors.warning,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Caja cerrada',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Para procesar un cobro necesitás tener la caja abierta. '
              'Abrila ahora con el fondo inicial del turno.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _opening
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _opening ? null : _onOpenCash,
                    icon: _opening
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.lock_open, size: 18),
                    label: Text(
                      _opening ? 'Abriendo…' : 'Abrir caja',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso no bloqueante: la caja lleva abierta desde ayer.
/// Permite continuar O ir a cerrar la caja del día anterior.
Future<void> _showStaleCashWarning(
    BuildContext context, DateTime openedAt) async {
  final timeStr =
      DateFormat('HH:mm').format(openedAt.toLocal());
  final dateStr = DateFormat('d MMM', 'es').format(openedAt.toLocal());

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.access_time_filled,
              color: AppColors.warning,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Caja abierta desde ayer',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'La caja está abierta desde el $dateStr a las $timeStr. '
            'Acordate de cerrar el turno anterior antes de continuar.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Continuar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    Get.toNamed('/cash-register');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Ir a caja',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
