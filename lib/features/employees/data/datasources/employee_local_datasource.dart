import '../../../../core/services/local_cache_service.dart';
import '../models/employee_model.dart';

abstract class EmployeeLocalDataSource {
  /// Devuelve la lista cacheada, o null si no hay caché o está vencida (>4h).
  Future<List<EmployeeModel>?> getCachedEmployees();

  /// Guarda el JSON crudo de la API en caché local.
  Future<void> cacheEmployees(List<Map<String, dynamic>> rawJsonList);

  /// True si la caché existe y tiene menos de 4 horas.
  bool get hasFreshCache;
}

class EmployeeLocalDataSourceImpl implements EmployeeLocalDataSource {
  final LocalCacheService cache;

  EmployeeLocalDataSourceImpl({required this.cache});

  @override
  Future<List<EmployeeModel>?> getCachedEmployees() async {
    if (cache.isStale(CacheKeys.employees, maxAge: CacheKeys.operationalTtl)) {
      return null;
    }
    final raw = cache.getList(CacheKeys.employees);
    if (raw == null) return null;
    return raw.map((e) => EmployeeModel.fromJson(e)).toList();
  }

  @override
  Future<void> cacheEmployees(List<Map<String, dynamic>> rawJsonList) async {
    await cache.saveList(CacheKeys.employees, rawJsonList);
  }

  @override
  bool get hasFreshCache =>
      !cache.isStale(CacheKeys.employees, maxAge: CacheKeys.operationalTtl);
}
