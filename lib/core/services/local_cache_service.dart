import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Servicio de caché local basado en Hive.
///
/// Diseño:
///   - Una Box llamada 'app_cache' guarda todos los datos.
///   - Cada entrada tiene una clave de datos (ej. 'products') y otra
///     clave de timestamp (ej. 'products_ts') que permite calcular si
///     el dato está vencido.
///   - No requiere code generation: guarda JSON como String.
///
/// Uso típico:
///   ```dart
///   // Guardar
///   await cache.save('products', products.map((p) => p.toJson()).toList());
///
///   // Leer
///   final raw = cache.get('products');  // List<Map<String, dynamic>>?
///   ```
class LocalCacheService {
  static const _boxName = 'app_cache';
  static const _tsSuffix = '_ts';

  late Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  // ─── WRITE ────────────────────────────────────────────────────────

  /// Guarda una lista de objetos JSON.
  Future<void> saveList(String key, List<Map<String, dynamic>> data) async {
    await _box.put(key, jsonEncode(data));
    await _box.put('$key$_tsSuffix', DateTime.now().toIso8601String());
  }

  /// Guarda un solo objeto JSON.
  Future<void> saveObject(String key, Map<String, dynamic> data) async {
    await _box.put(key, jsonEncode(data));
    await _box.put('$key$_tsSuffix', DateTime.now().toIso8601String());
  }

  /// Guarda un valor primitivo (string, int, bool).
  Future<void> saveValue(String key, dynamic value) async {
    await _box.put(key, value);
    await _box.put('$key$_tsSuffix', DateTime.now().toIso8601String());
  }

  // ─── READ ─────────────────────────────────────────────────────────

  /// Devuelve una lista de Maps, o null si no hay nada cacheado.
  List<Map<String, dynamic>>? getList(String key) {
    final raw = _box.get(key) as String?;
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.whereType<Map>().map((e) {
        return Map<String, dynamic>.from(e);
      }).toList();
    } catch (_) {
      return null;
    }
  }

  /// Devuelve un solo Map, o null si no hay nada cacheado.
  Map<String, dynamic>? getObject(String key) {
    final raw = _box.get(key) as String?;
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  /// Devuelve un valor primitivo.
  T? getValue<T>(String key) => _box.get(key) as T?;

  // ─── STALENESS ────────────────────────────────────────────────────

  /// Devuelve true si el dato NO existe o supera [maxAge].
  bool isStale(String key, {Duration maxAge = const Duration(hours: 12)}) {
    if (!_box.containsKey(key)) return true;
    final tsStr = _box.get('$key$_tsSuffix') as String?;
    if (tsStr == null) return true;
    final ts = DateTime.tryParse(tsStr);
    if (ts == null) return true;
    return DateTime.now().difference(ts) > maxAge;
  }

  /// Timestamp de la última sync, o null si nunca se sincronizó.
  DateTime? lastSyncedAt(String key) {
    final tsStr = _box.get('$key$_tsSuffix') as String?;
    if (tsStr == null) return null;
    return DateTime.tryParse(tsStr);
  }

  // ─── DELETE ───────────────────────────────────────────────────────

  /// Elimina la entrada y su timestamp.
  Future<void> invalidate(String key) async {
    await _box.delete(key);
    await _box.delete('$key$_tsSuffix');
  }

  /// Elimina TODA la caché (útil al hacer logout).
  Future<void> clearAll() async {
    await _box.clear();
  }
}

/// Claves de caché. Centralizar evita typos.
abstract class CacheKeys {
  static const products = 'products';
  static const categories = 'categories';
  static const employees = 'employees';
  static const customers = 'customers';
  static const printerConfigs = 'printer_configs';
  static const paymentAccounts = 'payment_accounts';
  static const tenantInfo = 'tenant_info';
  static const roles = 'roles';
  static const tables = 'tables';
  static const floorPlan = 'floor_plan';
  // TTLs específicos
  static const Duration catalogTtl = Duration(hours: 24);
  static const Duration operationalTtl = Duration(hours: 4);
  static const Duration configTtl = Duration(days: 7);
}
