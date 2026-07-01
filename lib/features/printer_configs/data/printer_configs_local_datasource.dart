import '../../../core/services/local_cache_service.dart';
import 'models/printer_config_model.dart';

abstract class PrinterConfigsLocalDataSource {
  /// Devuelve la lista cacheada, o null si no hay caché o está vencida (>7 días).
  Future<List<PrinterConfigModel>?> getCachedPrinterConfigs();

  /// Guarda el JSON crudo de la API en caché local.
  Future<void> cachePrinterConfigs(List<Map<String, dynamic>> rawJsonList);

  /// True si la caché existe y tiene menos de 7 días.
  bool get hasFreshCache;
}

class PrinterConfigsLocalDataSourceImpl implements PrinterConfigsLocalDataSource {
  final LocalCacheService cache;

  PrinterConfigsLocalDataSourceImpl({required this.cache});

  @override
  Future<List<PrinterConfigModel>?> getCachedPrinterConfigs() async {
    if (cache.isStale(CacheKeys.printerConfigs, maxAge: CacheKeys.configTtl)) {
      return null;
    }
    final raw = cache.getList(CacheKeys.printerConfigs);
    if (raw == null) return null;
    return raw.map((e) => PrinterConfigModel.fromJson(e)).toList();
  }

  @override
  Future<void> cachePrinterConfigs(List<Map<String, dynamic>> rawJsonList) async {
    await cache.saveList(CacheKeys.printerConfigs, rawJsonList);
  }

  @override
  bool get hasFreshCache =>
      !cache.isStale(CacheKeys.printerConfigs, maxAge: CacheKeys.configTtl);
}
