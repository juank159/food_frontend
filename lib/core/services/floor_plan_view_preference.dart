import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../utils/api_response_utils.dart';

/// Vista preferida ("lista" o "mapa") con la que el tenant quiere que
/// arranque siempre "Estado de Mesas" — se guarda en
/// `settings.floor_plan_view.default_view` (mismo patrón que
/// `OperationModePreference`/`settings.operation_mode`: merge manual
/// sobre `PATCH /tenants/me`, sin endpoint dedicado).
///
/// **Por qué no un botón de "guardar" aparte:** el mismo toggle de
/// lista/mapa que ya existe en la pantalla GUARDA la elección al
/// tocarlo — así, "predefinir la vista" es tan simple como dejarla en
/// la que uno prefiere una vez; no hace falta ir a Ajustes.
class FloorPlanViewPreference {
  FloorPlanViewPreference._();

  static const String defaultView = 'list';

  static String? _cachedView;
  static DateTime? _cachedAt;

  /// `'list'` o `'map'`. Cacheado 10 min — el negocio no cambia esto
  /// seguido, no vale la pena pedir `/tenants/me` en cada apertura.
  static Future<String> getDefaultView() async {
    final now = DateTime.now();
    if (_cachedAt != null &&
        now.difference(_cachedAt!) < const Duration(minutes: 10)) {
      return _cachedView ?? defaultView;
    }
    try {
      final dio = GetIt.I<Dio>();
      final res = await dio.get('/tenants/me');
      final tenant = ApiResponseUtils.object(res);
      final settings =
          (tenant['settings'] as Map?)?.cast<String, dynamic>() ?? {};
      final floorPlanView =
          (settings['floor_plan_view'] as Map?)?.cast<String, dynamic>() ??
              {};
      final value = floorPlanView['default_view'] as String?;
      _cachedView = (value == 'map') ? 'map' : defaultView;
      _cachedAt = now;
      return _cachedView!;
    } catch (_) {
      // Sin conexión / error: no forzamos ningún default distinto al
      // de siempre — la pantalla sigue usable, solo no recuerda la
      // preferencia esta vez.
      return defaultView;
    }
  }

  /// Guarda [view] (`'list'` o `'map'`) como la vista por defecto del
  /// tenant. Fire-and-forget desde el caller: un fallo acá no debe
  /// bloquear que el usuario siga viendo la pantalla en la vista que
  /// acaba de elegir, solo falla en recordarla la próxima vez.
  static Future<void> setDefaultView(String view) async {
    _cachedView = view;
    _cachedAt = DateTime.now();
    try {
      final dio = GetIt.I<Dio>();
      final res = await dio.get('/tenants/me');
      final tenant = ApiResponseUtils.object(res);
      final existing =
          (tenant['settings'] as Map?)?.cast<String, dynamic>() ?? {};
      final newSettings = Map<String, dynamic>.from(existing);
      newSettings['floor_plan_view'] = {'default_view': view};
      await dio.patch('/tenants/me', data: {'settings': newSettings});
    } catch (_) {
      // Silencioso a propósito — ver docstring.
    }
  }
}
