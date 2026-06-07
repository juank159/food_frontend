// lib/features/tables/data/repositories/floor_plan_repository_impl.dart

import '../../domain/entities/floor_plan.dart';
import '../../domain/repositories/floor_plan_repository.dart';
import '../datasources/floor_plan_datasource.dart';
import '../../core/utils/logger.dart';

/// Implementación del repositorio con cache y retry logic
class FloorPlanRepositoryImpl implements FloorPlanRepository {
  final FloorPlanDataSource dataSource;

  // Cache en memoria con TTL
  final Map<String, _CachedFloorPlan> _cache = {};
  final Map<String, _CachedFloorPlanList> _listCache = {};

  // Configuración de cache
  static const _cacheDuration = Duration(minutes: 5);
  static const _maxRetries = 3;
  static const _retryDelay = Duration(seconds: 1);

  FloorPlanRepositoryImpl({required this.dataSource});

  @override
  Future<List<FloorPlan>> getFloorPlans() async {
    const cacheKey = 'all_floor_plans';

    // Verificar cache
    if (_listCache.containsKey(cacheKey) && !_listCache[cacheKey]!.isExpired) {
      tablesLogger.d('Floor plans obtenidos de cache');
      return _listCache[cacheKey]!.data;
    }

    // Fetch con retry
    try {
      final data = await _retryOperation(() => dataSource.getFloorPlans());

      // Guardar en cache
      _listCache[cacheKey] = _CachedFloorPlanList(data);

      tablesLogger.d('Floor plans cargados exitosamente (${data.length} items)');
      return data;
    } catch (e) {
      tablesLogger.e('Error obteniendo floor plans', error: e);
      throw Exception('Error obteniendo floor plans: $e');
    }
  }

  @override
  Future<FloorPlan> getFloorPlanById(String id) async {
    // Verificar cache
    if (_cache.containsKey(id) && !_cache[id]!.isExpired) {
      tablesLogger.d('Floor plan $id obtenido de cache');
      return _cache[id]!.data;
    }

    // Fetch con retry
    try {
      final data = await _retryOperation(() => dataSource.getFloorPlanById(id));

      // Guardar en cache
      _cache[id] = _CachedFloorPlan(data);

      tablesLogger.d('Floor plan $id cargado exitosamente');
      return data;
    } catch (e) {
      tablesLogger.e('Error obteniendo floor plan $id', error: e);
      throw Exception('Error obteniendo floor plan: $e');
    }
  }

  @override
  Future<FloorPlan> createFloorPlan(FloorPlan floorPlan) async {
    try {
      final data = await _retryOperation(() => dataSource.createFloorPlan(floorPlan));

      // Invalidar cache de lista
      _listCache.clear();

      tablesLogger.i('Floor plan creado exitosamente: ${data.id}');
      return data;
    } catch (e) {
      tablesLogger.e('Error creando floor plan', error: e);
      throw Exception('Error creando floor plan: $e');
    }
  }

  @override
  Future<FloorPlan> updateFloorPlan(String id, FloorPlan floorPlan) async {
    try {
      final data = await _retryOperation(() => dataSource.updateFloorPlan(id, floorPlan));

      // Invalidar cache específico y de lista
      _cache.remove(id);
      _listCache.clear();

      tablesLogger.i('Floor plan actualizado exitosamente: $id');
      return data;
    } catch (e) {
      tablesLogger.e('Error actualizando floor plan $id', error: e);
      throw Exception('Error actualizando floor plan: $e');
    }
  }

  @override
  Future<void> deleteFloorPlan(String id) async {
    try {
      await _retryOperation(() => dataSource.deleteFloorPlan(id));

      // Invalidar cache
      _cache.remove(id);
      _listCache.clear();

      tablesLogger.i('Floor plan eliminado exitosamente: $id');
    } catch (e) {
      tablesLogger.e('Error eliminando floor plan $id', error: e);
      throw Exception('Error eliminando floor plan: $e');
    }
  }

  @override
  Future<FloorPlan> duplicateFloorPlan(String id, String newName) async {
    try {
      final data = await _retryOperation(() => dataSource.duplicateFloorPlan(id, newName));

      // Invalidar cache de lista
      _listCache.clear();

      tablesLogger.i('Floor plan duplicado exitosamente: ${data.id}');
      return data;
    } catch (e) {
      tablesLogger.e('Error duplicando floor plan $id', error: e);
      throw Exception('Error duplicando floor plan: $e');
    }
  }

  /// Ejecuta una operación con retry logic
  Future<T> _retryOperation<T>(Future<T> Function() operation) async {
    int attempts = 0;
    Exception? lastException;

    while (attempts < _maxRetries) {
      try {
        return await operation();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        attempts++;

        if (attempts < _maxRetries) {
          tablesLogger.w('Intento $attempts de $_maxRetries falló, reintentando...', error: e);
          await Future.delayed(_retryDelay * attempts); // Backoff exponencial
        }
      }
    }

    throw lastException ?? Exception('Operación falló después de $_maxRetries intentos');
  }

  /// Limpia todo el cache
  void clearCache() {
    _cache.clear();
    _listCache.clear();
    tablesLogger.d('Cache limpiado');
  }
}

/// Clase helper para cachear floor plans individuales
class _CachedFloorPlan {
  final FloorPlan data;
  final DateTime timestamp;

  _CachedFloorPlan(this.data) : timestamp = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(timestamp) > FloorPlanRepositoryImpl._cacheDuration;
}

/// Clase helper para cachear listas de floor plans
class _CachedFloorPlanList {
  final List<FloorPlan> data;
  final DateTime timestamp;

  _CachedFloorPlanList(this.data) : timestamp = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(timestamp) > FloorPlanRepositoryImpl._cacheDuration;
}
