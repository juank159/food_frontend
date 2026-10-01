import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../utils/api_response_utils.dart';

/// Cache liviano de `settings.operation_mode` del tenant — espejo del
/// `OperationMode` enum del backend (`common/constants/enums.ts`):
/// 'tables' | 'open_tabs' | 'counter_tickets' | 'mixed'.
///
/// Nunca bloquea nada a nivel backend (sigue siendo una preferencia, no
/// una regla de negocio dura) — pero el frontend SÍ la usa para
/// simplificar la experiencia cuando un negocio declaró un modo
/// EXCLUSIVO:
///   - `counter_tickets` (solo turnos): `SellModeSheet` oculta toda la
///     sección "Mesa o cuenta abierta" — ver `isCounterTicketsOnly`.
///   - `tables` (solo mesas): `SellModeSheet` oculta "Venta rápida"
///     (mostrador/turno/para llevar/domicilio sueltos) y "Nueva cuenta
///     libre" — ver `isTablesOnly`. Para llevar/domicilio NO
///     desaparecen del todo: siguen disponibles como un ticket más
///     dentro de la cuenta de una mesa ya abierta.
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

  /// `true` si el negocio configuró "Por mesas" como su único modo de
  /// operación. A diferencia de `isCounterTicketsOnly` (que oculta
  /// mesas/cuentas), acá es al revés: se oculta vender SIN mesa
  /// (mostrador, turno, para llevar/domicilio sueltos, cuenta libre).
  /// Para llevar/domicilio NO desaparecen del todo — siguen
  /// disponibles como un ticket más dentro de la cuenta de una mesa.
  static Future<bool> isTablesOnly() async {
    final mode = await _getMode();
    return mode == 'tables';
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
