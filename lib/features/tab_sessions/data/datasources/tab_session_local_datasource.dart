import '../../../../core/services/local_cache_service.dart';
import '../models/tab_session_model.dart';

/// Caché de las cuentas abiertas (mesas + delivery activos) — mismo
/// patrón que `ProductLocalDataSource` (ver ese archivo para el
/// porqué completo). Las cuentas abiertas son datos operativos vivos
/// (saldo, items), así que el TTL es corto — igual que orders.
abstract class TabSessionLocalDataSource {
  Future<List<TabSessionModel>?> getCachedOpenTabs();
  Future<void> cacheOpenTabs(List<Map<String, dynamic>> rawJsonList);

  /// Caché SIN importar su edad — para pintado "local-first".
  Future<List<TabSessionModel>?> peekCachedOpenTabs();
}

class TabSessionLocalDataSourceImpl implements TabSessionLocalDataSource {
  static const _cacheTtl = Duration(hours: 1);

  final LocalCacheService cache;

  TabSessionLocalDataSourceImpl({required this.cache});

  @override
  Future<List<TabSessionModel>?> getCachedOpenTabs() async {
    if (cache.isStale(CacheKeys.openTabSessions, maxAge: _cacheTtl)) return null;
    final raw = cache.getList(CacheKeys.openTabSessions);
    if (raw == null) return null;
    return raw.map((e) => TabSessionModel.fromJson(e)).toList();
  }

  @override
  Future<void> cacheOpenTabs(List<Map<String, dynamic>> rawJsonList) async {
    await cache.saveList(CacheKeys.openTabSessions, rawJsonList);
  }

  @override
  Future<List<TabSessionModel>?> peekCachedOpenTabs() async {
    final raw = cache.getList(CacheKeys.openTabSessions);
    if (raw == null) return null;
    return raw.map((e) => TabSessionModel.fromJson(e)).toList();
  }
}
