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

  /// Parcha (por id) los campos editables de una cuenta dentro de la
  /// caché de cuentas abiertas — para que renombrar la "etiqueta"
  /// (customerName/notes) o el partySize offline sobreviva un reinicio
  /// mientras la mutación real sigue en cola. Mismo patrón que
  /// `OrderLocalDataSource.updateCachedOrder`. `null` en un parámetro
  /// significa "no tocar ese campo" (igual que en
  /// `TabSessionRepositoryImpl.update`), no "borrarlo".
  Future<void> patchCachedOpenTab(
    String id, {
    String? customerName,
    String? notes,
    int? partySize,
  });
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

  @override
  Future<void> patchCachedOpenTab(
    String id, {
    String? customerName,
    String? notes,
    int? partySize,
  }) async {
    final raw = cache.getList(CacheKeys.openTabSessions);
    if (raw == null) return;
    var found = false;
    final patched = raw.map((j) {
      if (j['id'] != id) return j;
      found = true;
      final updated = Map<String, dynamic>.from(j);
      if (customerName != null) updated['customer_name'] = customerName;
      if (notes != null) updated['notes'] = notes;
      if (partySize != null) updated['party_size'] = partySize;
      return updated;
    }).toList();
    if (!found) return;
    await cache.saveList(CacheKeys.openTabSessions, patched);
  }
}
