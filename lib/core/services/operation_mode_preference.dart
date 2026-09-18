import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../utils/api_response_utils.dart';

/// Cache liviano de `settings.operation_mode` del tenant — espejo del
/// `OperationMode` enum del backend (`common/constants/enums.ts`):
/// 'tables' | 'open_tabs' | 'counter_tickets' | 'mixed'.
///
/// Es SOLO una preferencia (confirmado con el negocio: nunca bloquea
/// nada a nivel backend) — pero el frontend sí la usa para simplificar
/// la experiencia cuando un negocio declaró que opera EXCLUSIVAMENTE
/// por turnos de mostrador (sin mesas ni cuentas abiertas):
///   - `SellPage` arranca directo en `SellMode.counterTicket()`.
///   - `SellModeSheet` oculta la sección "Mesa o cuenta abierta".
///
/// Cacheado 10 min (mismo TTL que `PrintingOrchestrator._getTenantInfo`)
/// — el negocio cambia esto rarísima vez, no vale la pena pedir
/// `/tenants/me` en cada apertura de la pantalla de venta.
class OperationModePreference {
  OperationModePreference._();

  static String? _cachedMode;
  static DateTime? _cachedAt;

  /// `true` si el negocio configuró "Turnos de mostrador" como su
  /// único modo de operación.
  static Future<bool> isCounterTicketsOnly() async {
    final mode = await _getMode();
    return mode == 'counter_tickets';
  }

  static Future<String?> _getMode() async {
    final now = DateTime.now();
    if (_cachedAt != null &&
        now.difference(_cachedAt!) < const Duration(minutes: 10)) {
      return _cachedMode;
    }
    try {
      final dio = GetIt.I<Dio>();
      final res = await dio.get('/tenants/me');
      final tenant = ApiResponseUtils.object(res);
      final settings =
          (tenant['settings'] as Map?)?.cast<String, dynamic>() ?? {};
      final operationMode =
          (settings['operation_mode'] as Map?)?.cast<String, dynamic>() ?? {};
      _cachedMode = operationMode['mode'] as String?;
      _cachedAt = now;
      return _cachedMode;
    } catch (_) {
      // Sin conexión / error: no forzamos ningún modo por defecto.
      return null;
    }
  }

  /// Si el negocio actualiza su modo de operación desde Ajustes, llamar
  /// a esto para que el próximo `SellPage` lo refleje sin esperar el TTL.
  static void invalidateCache() {
    _cachedMode = null;
    _cachedAt = null;
  }
}
