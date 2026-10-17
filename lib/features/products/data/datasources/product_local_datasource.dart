import '../../../../core/services/local_cache_service.dart';
import '../models/product_model.dart';

abstract class ProductLocalDataSource {
  /// Devuelve la lista cacheada, o null si no hay caché o está vencida (>24h).
  Future<List<ProductModel>?> getCachedProducts();

  /// Guarda el JSON crudo de la API en caché local.
  Future<void> cacheProducts(List<Map<String, dynamic>> rawJsonList);

  /// Busca un producto por id en la lista cacheada. Devuelve null si no existe.
  Future<ProductModel?> getCachedProductById(String id);

  /// True si la caché existe y tiene menos de 24 horas.
  bool get hasFreshCache;

  /// Devuelve la lista cacheada SIN importar qué tan vieja sea — a
  /// diferencia de `getCachedProducts()` (que respeta el TTL de 24h y
  /// devuelve null si venció). Se usa para el pintado "local-first":
  /// mejor mostrar el catálogo (aunque tenga horas) YA, que hacer
  /// esperar al usuario a la red cada vez que abre la pantalla. La
  /// llamada de red que sigue atrás refresca esto para la próxima vez.
  Future<List<ProductModel>?> peekCachedProducts();
}

class ProductLocalDataSourceImpl implements ProductLocalDataSource {
  final LocalCacheService cache;

  ProductLocalDataSourceImpl({required this.cache});

  @override
  Future<List<ProductModel>?> getCachedProducts() async {
    if (cache.isStale(CacheKeys.products, maxAge: CacheKeys.catalogTtl)) {
      return null;
    }
    final raw = cache.getList(CacheKeys.products);
    if (raw == null) return null;
    return raw.map((e) => ProductModel.fromJson(e)).toList();
  }

  @override
  Future<void> cacheProducts(List<Map<String, dynamic>> rawJsonList) async {
    await cache.saveList(CacheKeys.products, rawJsonList);
  }

  @override
  Future<ProductModel?> getCachedProductById(String id) async {
    final raw = cache.getList(CacheKeys.products);
    if (raw == null) return null;
    final match = raw.cast<Map<String, dynamic>?>().firstWhere(
      (e) => e != null && e['id'] == id,
      orElse: () => null,
    );
    if (match == null) return null;
    return ProductModel.fromJson(match);
  }

  @override
  bool get hasFreshCache =>
      !cache.isStale(CacheKeys.products, maxAge: CacheKeys.catalogTtl);

  @override
  Future<List<ProductModel>?> peekCachedProducts() async {
    final raw = cache.getList(CacheKeys.products);
    if (raw == null) return null;
    return raw.map((e) => ProductModel.fromJson(e)).toList();
  }
}
