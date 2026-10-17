import '../../../../core/services/local_cache_service.dart';
import '../models/category_model.dart';

abstract class CategoryLocalDataSource {
  Future<List<CategoryModel>?> getCachedCategories();
  Future<void> cacheCategories(List<Map<String, dynamic>> rawJsonList);
  bool get hasFreshCache;

  /// Caché SIN importar su edad — para pintado "local-first" (ver
  /// `ProductLocalDataSource.peekCachedProducts`, mismo patrón).
  Future<List<CategoryModel>?> peekCachedCategories();

  /// Agrega una categoría creada offline (id temporal `local_...`) a
  /// la caché de la lista, para que aparezca de inmediato en cualquier
  /// pantalla que la lea y sobreviva un reinicio mientras la creación
  /// real sigue en cola. No falla si todavía no hay caché — crea una
  /// lista nueva con un solo elemento.
  Future<void> addCachedCategory(CategoryModel category);
}

class CategoryLocalDataSourceImpl implements CategoryLocalDataSource {
  final LocalCacheService cache;

  CategoryLocalDataSourceImpl({required this.cache});

  @override
  Future<List<CategoryModel>?> getCachedCategories() async {
    if (cache.isStale(CacheKeys.categories, maxAge: CacheKeys.catalogTtl)) {
      return null;
    }
    final raw = cache.getList(CacheKeys.categories);
    if (raw == null) return null;
    return raw
        .map((e) => CategoryModel.fromJson(e))
        .toList();
  }

  @override
  Future<void> cacheCategories(List<Map<String, dynamic>> rawJsonList) async {
    await cache.saveList(CacheKeys.categories, rawJsonList);
  }

  @override
  bool get hasFreshCache =>
      !cache.isStale(CacheKeys.categories, maxAge: CacheKeys.catalogTtl);

  @override
  Future<List<CategoryModel>?> peekCachedCategories() async {
    final raw = cache.getList(CacheKeys.categories);
    if (raw == null) return null;
    return raw.map((e) => CategoryModel.fromJson(e)).toList();
  }

  @override
  Future<void> addCachedCategory(CategoryModel category) async {
    final raw = cache.getList(CacheKeys.categories) ?? [];
    await cache.saveList(CacheKeys.categories, [...raw, category.toJson()]);
  }
}
