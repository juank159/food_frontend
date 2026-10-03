import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/routes/navigation_service.dart';
import '../../../../core/utils/app_dialog.dart';
import '../../../../core/utils/ui_access.dart';
import '../../../auth/domain/entities/user.dart';
import '../../domain/usecases/get_usage_usecase.dart';

/// **Servicio singleton** que recuerda, cada 2 horas, que el trial está
/// por vencer (queda 1 día o menos) — una vez que se cumpla ese día, el
/// backend bloquea crear pedidos, cobrar, registrar gastos y nómina
/// hasta que se elija un plan (`TenantInterceptor.assertCanCreate`).
///
/// Mismo patrón que `PendingReviewWatcher`: `GetxService` permanente,
/// arrancado desde `AuthController` (login + restauración de sesión al
/// abrir la app) y detenido al cerrar sesión. Poll con
/// `Timer.periodic` en vez de WebSocket — mismo criterio de ese watcher
/// (simplicidad, volumen bajo, nadie necesita saberlo al segundo).
///
/// **Solo para admin**: es el único rol que puede ver/cambiar el plan
/// (`UiAccess.canSeeSubscription`) — mostrarle este aviso a un
/// mesero/cajero sería ruido que no puede resolver, y expone info de
/// facturación a quien no le corresponde.
class TrialExpiryReminderService extends GetxService {
  TrialExpiryReminderService({
    GetUsageUseCase? getUsageUseCase,
    Duration checkInterval = const Duration(hours: 2),
  })  : _getUsage = getUsageUseCase ?? sl<GetUsageUseCase>(),
        _checkInterval = checkInterval;

  final GetUsageUseCase _getUsage;
  final Duration _checkInterval;
  Timer? _timer;
  bool _active = false;

  /// `user` viene del login/restauración de sesión. Si el rol no es
  /// admin, no arranca (o detiene si ya estaba corriendo de una sesión
  /// anterior con otro rol en el mismo dispositivo).
  void startForUser(User? user) {
    if (!UiAccess.from(user).isAdmin) {
      stop();
      return;
    }
    if (_active) return;
    _active = true;

    _tick(); // chequeo inmediato — no esperar 2h si ya está por vencer
    _timer = Timer.periodic(_checkInterval, (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _active = false;
  }

  Future<void> _tick() async {
    try {
      final result = await _getUsage();
      result.fold(
        (_) {}, // red caída / 401 / etc — el próximo tick reintenta
        (usage) {
          final daysLeft = usage.trialDaysRemaining;
          if (usage.isTrialActive && daysLeft <= 1) {
            _showReminder(daysLeft);
          }
        },
      );
    } catch (_) {
      // Este servicio NUNCA debe tumbar la app — ni por un error de
      // red ni por nada de lo que dependa `AppDialog`/`Get`.
    }
  }

  void _showReminder(int daysLeft) {
    // No interrumpir si ya hay un dialog más urgente en pantalla (ej.
    // el de pedidos QR nuevos) — el próximo tick (2h) vuelve a intentar.
    try {
      if (Get.isDialogOpen == true) return;
    } catch (_) {
      return;
    }

    final title =
        daysLeft <= 0 ? 'Tu prueba vence hoy' : 'Tu prueba vence mañana';

    AppDialog.show<void>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade800,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Cuando termine, no vas a poder crear pedidos, cobrar, '
          'registrar gastos ni nómina hasta que elijas un plan. '
          'Hacelo ahora para no quedarte sin operar.',
          style: TextStyle(fontSize: 15),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          OutlinedButton(
            onPressed: () => Get.back(),
            child: const Text('Ahora no'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Elegir plan'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
            ),
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

  @override
  void onClose() {
    stop();
    super.onClose();
  }
}
