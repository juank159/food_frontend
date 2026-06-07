import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/cash_session_usecases.dart';
import '../controllers/cash_session_controller.dart';
import '../controllers/cash_session_guard.dart';
import 'open_cash_dialog.dart';

/// Detecta si un mensaje de failure viene con el prefijo
/// `CASH_SESSION_REQUIRED:` que mandamos desde el backend cuando
/// el cajero intenta cobrar en efectivo sin caja abierta.
///
/// El prefijo se agrega en `payment_remote_datasource.dart._handleError`
/// — el server pone `{code: CASH_SESSION_REQUIRED, message: ...}` y el
/// datasource lo aplana a `CASH_SESSION_REQUIRED:<msg>` para que los
/// controllers existentes lo detecten sin nuevos tipos de excepción.
bool isCashSessionRequiredError(String message) {
  return message.startsWith('CASH_SESSION_REQUIRED');
}

/// Si el error es por falta de caja, muestra un dialog modal explicando
/// el problema y ofreciendo abrir caja ahora mismo. Devuelve `true` si
/// el cajero abrió caja desde el dialog (el caller puede reintentar el
/// cobro automáticamente).
///
/// Si el error NO es por falta de caja, devuelve `false` sin mostrar
/// nada — el caller debe seguir con su snackbar de error genérico.
Future<bool> handleCashSessionError(String message) async {
  if (!isCashSessionRequiredError(message)) return false;

  // Auto-registrar el controller del dialog de apertura si no estamos
  // viniendo desde /cash-register.
  if (!Get.isRegistered<CashSessionController>()) {
    Get.put<CashSessionController>(
      CashSessionController(useCases: sl<CashSessionUseCases>()),
    );
  }

  final didOpen = await Get.dialog<bool>(
    Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.point_of_sale,
                      color: AppColors.warning,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Necesitás abrir caja',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Para cobrar en efectivo necesitás una caja abierta. '
                'Podés abrirla ahora mismo sin perder este cobro — '
                'después de abrir, volvé a intentar.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(result: false),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      // Cerramos este dialog ANTES de abrir el siguiente
                      // para que Navigator no quede con dos modales.
                      Get.back(result: false);
                      final opened = await Get.dialog<bool>(
                        const OpenCashDialog(),
                        barrierDismissible: false,
                      );
                      if (opened == true) {
                        cashGuard().markOpened();
                      }
                    },
                    icon: const Icon(Icons.lock_open, size: 18),
                    label: const Text('Abrir caja ahora'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    barrierDismissible: false,
  );

  // Independiente del flujo: aunque devolvamos true/false, ya manejamos
  // el error — el caller NO debe mostrar snackbar adicional.
  return didOpen == true;
}
