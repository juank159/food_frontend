// lib/core/utils/api_response_utils.dart
import 'package:dio/dio.dart';
import '../error/exceptions.dart';

/// ApiResponseUtils — helpers defensivos para parsear respuestas del
/// backend.
///
/// **Por qué existe:**
///
/// El backend devuelve respuestas con FORMATOS DISTINTOS según el
/// endpoint:
///
///   - `[item1, item2, ...]`                    ← lista directa
///   - `{data: [...]}`                          ← envuelta simple
///   - `{data: [...], meta: {...}}`             ← envuelta con paginación
///   - `{data: {data: [...], total, page}}`     ← envoltura doble (legacy)
///
/// Asumir solo uno (ej. `response.data['data']`) crashea con
/// `type 'String' is not a subtype of type 'int' of 'index'` cuando
/// el backend devuelve `[...]` directo y se intenta indexar una `List`
/// con un string.
///
/// **Cómo usar:**
///
/// ```dart
/// final response = await dio.get(...);
///
/// // Para detalle / objeto único:
/// final json = ApiResponseUtils.extractObject(response);
///
/// // Para listas:
/// final items = ApiResponseUtils.extractList(response)
///     .whereType<Map<String, dynamic>>()
///     .map(MyModel.fromJson)
///     .toList();
///
/// // Para metadata de paginación:
/// final meta = ApiResponseUtils.extractMeta(response);
/// ```
class ApiResponseUtils {
  ApiResponseUtils._();

  /// Extrae un Map de la respuesta. Soporta:
  ///   - `{...}` plano
  ///   - `{data: {...}}` envuelto
  Map<String, dynamic> extractObject(Response response) {
    final raw = response.data;
    if (raw is Map<String, dynamic>) {
      final inner = raw['data'];
      if (inner is Map<String, dynamic>) return inner;
      return raw;
    }
    throw ServerException(
      'Formato de respuesta inesperado (no es Map): ${raw.runtimeType}',
    );
  }

  /// Versión estática para no instanciar.
  static Map<String, dynamic> object(Response response) =>
      _instance.extractObject(response);

  /// Extrae una `List<dynamic>` de la respuesta. Soporta:
  ///   - `[...]` directo
  ///   - `{data: [...]}` envuelto
  ///   - `{data: {data: [...]}}` envoltura doble
  List<dynamic> extractList(Response response) {
    final raw = response.data;
    if (raw is List) return raw;
    if (raw is Map<String, dynamic>) {
      final inner = raw['data'];
      if (inner is List) return inner;
      if (inner is Map<String, dynamic>) {
        final nested = inner['data'];
        if (nested is List) return nested;
      }
    }
    throw ServerException(
      'Formato de respuesta inesperado (no es List): ${raw.runtimeType}',
    );
  }

  /// Versión estática para no instanciar.
  static List<dynamic> list(Response response) =>
      _instance.extractList(response);

  /// Extrae el bloque `meta` de paginación. Soporta:
  ///   - `{data: [...], meta: {...}}`        → devuelve `meta`
  ///   - `{data: {data: [...], total, ...}}` → devuelve `data` (legacy)
  ///   - cualquier otro → `null`
  ///
  /// El caller decide qué hacer con `null` (default values).
  Map<String, dynamic>? extractMeta(Response response) {
    final raw = response.data;
    if (raw is! Map<String, dynamic>) return null;
    final meta = raw['meta'];
    if (meta is Map<String, dynamic>) return meta;
    final data = raw['data'];
    if (data is Map<String, dynamic>) {
      // Detectar formato legacy: data.total + data.page + data.data
      if (data.containsKey('total') || data.containsKey('page')) {
        return data;
      }
    }
    return null;
  }

  /// Versión estática para no instanciar.
  static Map<String, dynamic>? meta(Response response) =>
      _instance.extractMeta(response);

  /// Extrae un mensaje de error del body de un DioException de forma
  /// 100% defensiva — NUNCA lanza, sin importar la forma del `data`.
  ///
  /// Maneja todos los casos reales que devuelve el stack:
  ///   - body JSON `{ "message": "..." }` o `{ "message": [...] }` (NestJS
  ///     validation devuelve un array de mensajes).
  ///   - body JSON `{ "error": "..." }`.
  ///   - body **texto plano** (ej. 502 "Bad Gateway", 504 del proxy,
  ///     HTML de error) → lo devuelve tal cual. ESTE es el caso que
  ///     crasheaba al hacer `data['message']` sobre un String (indexar
  ///     un String con un String → TypeError).
  ///   - cualquier otra cosa → `null` (el caller usa su fallback).
  ///
  /// Acepta `dynamic` para poder pasarle también un `Object e` de un
  /// `catch` sin castear.
  static String? errorMessage(Object? error) {
    if (error is! DioException) return null;
    final data = error.response?.data;

    if (data is Map) {
      final msg = data['message'] ?? data['error'];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
      if (msg is List && msg.isNotEmpty) {
        return msg.map((e) => e.toString()).join(', ');
      }
      if (msg != null) return msg.toString();
    }
    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    return null;
  }

  static final ApiResponseUtils _instance = ApiResponseUtils._();
}
