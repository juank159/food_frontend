import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_dialog.dart';
import '../routes/navigation_service.dart';

/// Diálogo bloqueante que se muestra cuando el backend corta una
/// acción con `403 SUBSCRIPTION_REQUIRED` (trial vencido, sin plan
/// pago — ver `RequiresActivePlan`/`TenantInterceptor.assertCanCreate`
/// en el backend).
///
/// Bug real reportado: antes de esto, ese 403 solo se veía como
/// cualquier otro error (snackbar genérico con el mensaje crudo del
/// backend) — pedido explícito: "si un cliente se las quiere dar de
/// vivo, no pagarme, que no le permita avanzar, que haya un diálogo".
/// Mismo estilo que `TrialExpiryReminderService` (el aviso PREVIO al
/// vencimiento) para que todo el flujo de suscripción se vea
/// consistente — ese avisa antes, este bloquea cuando ya pasó.
///
/// Se llama desde el interceptor global de Dio (ver
/// `injection_container.dart`) — corre para CUALQUIER request
/// bloqueada por esto, sin importar qué pantalla la disparó.
void showSubscriptionBlockedDialog(String message) {
  try {
    if (Get.isDialogOpen == true) return;
  } catch (_) {
    return;
  }

  AppDialog.show<void>(
    AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_clock, color: Colors.red.shade800, size: 28),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Necesitás un plan activo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Text(message, style: const TextStyle(fontSize: 15)),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: [
        OutlinedButton(
          onPressed: () => Get.back(),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Elegir plan'),
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
          onPressed: () {
            Get.back();
            NavigationService.toSubscriptionPlans();
          },
        ),
      ],
    ),
    barrierDismissible: true,
  );
}
