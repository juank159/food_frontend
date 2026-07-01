import '../../../../core/services/local_cache_service.dart';

abstract class TenantPaymentAccountLocalDataSource {
  /// Devuelve la lista cacheada como mapas crudos, o null si no hay caché
  /// válida o está vencida (>7 días).
  Future<List<dynamic>?> getCachedAccounts();

  /// Guarda el JSON crudo de la API en caché local.
  Future<void> cacheAccounts(List<Map<String, dynamic>> rawJsonList);

  /// True si la caché existe y tiene menos de 7 días.
  bool get hasFreshCache;
}

class TenantPaymentAccountLocalDataSourceImpl
    implements TenantPaymentAccountLocalDataSource {
  final LocalCacheService cache;

  TenantPaymentAccountLocalDataSourceImpl({required this.cache});

  @override
  Future<List<dynamic>?> getCachedAccounts() async {
    if (cache.isStale(
      CacheKeys.paymentAccounts,
      maxAge: CacheKeys.configTtl,
    )) {
      return null;
    }
    return cache.getList(CacheKeys.paymentAccounts);
  }

  @override
  Future<void> cacheAccounts(List<Map<String, dynamic>> rawJsonList) async {
    await cache.saveList(CacheKeys.paymentAccounts, rawJsonList);
  }

  @override
  bool get hasFreshCache => !cache.isStale(
        CacheKeys.paymentAccounts,
        maxAge: CacheKeys.configTtl,
      );
}
