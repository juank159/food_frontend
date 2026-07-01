import '../../../../core/services/local_cache_service.dart';
import '../models/customer_model.dart';

abstract class CustomerLocalDataSource {
  /// Devuelve la lista cacheada, o null si no hay caché o está vencida (>4h).
  Future<List<CustomerModel>?> getCachedCustomers();

  /// Guarda el JSON crudo de la API en caché local.
  Future<void> cacheCustomers(List<Map<String, dynamic>> rawJsonList);

  /// Busca un cliente por teléfono en la lista cacheada. Devuelve null si no existe.
  Future<CustomerModel?> findByPhone(String phone);

  /// True si la caché existe y tiene menos de 4 horas.
  bool get hasFreshCache;
}

class CustomerLocalDataSourceImpl implements CustomerLocalDataSource {
  final LocalCacheService cache;

  CustomerLocalDataSourceImpl({required this.cache});

  @override
  Future<List<CustomerModel>?> getCachedCustomers() async {
    if (cache.isStale(CacheKeys.customers, maxAge: CacheKeys.operationalTtl)) {
      return null;
    }
    final raw = cache.getList(CacheKeys.customers);
    if (raw == null) return null;
    return raw.map((e) => CustomerModel.fromJson(e)).toList();
  }

  @override
  Future<void> cacheCustomers(List<Map<String, dynamic>> rawJsonList) async {
    await cache.saveList(CacheKeys.customers, rawJsonList);
  }

  @override
  Future<CustomerModel?> findByPhone(String phone) async {
    final raw = cache.getList(CacheKeys.customers);
    if (raw == null) return null;
    final match = raw.cast<Map<String, dynamic>?>().firstWhere(
      (e) => e != null && (e['phone'] as String?) == phone,
      orElse: () => null,
    );
    if (match == null) return null;
    return CustomerModel.fromJson(match);
  }

  @override
  bool get hasFreshCache =>
      !cache.isStale(CacheKeys.customers, maxAge: CacheKeys.operationalTtl);
}
