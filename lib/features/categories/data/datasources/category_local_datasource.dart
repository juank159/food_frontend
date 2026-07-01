import '../../../../core/services/local_cache_service.dart';
import '../models/category_model.dart';

abstract class CategoryLocalDataSource {
  Future<List<CategoryModel>?> getCachedCategories();
  Future<void> cacheCategories(List<Map<String, dynamic>> rawJsonList);
  bool get hasFreshCache;
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
}
