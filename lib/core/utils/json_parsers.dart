// lib/core/utils/json_parsers.dart

/// JsonParsers — funciones de coerción para `json_serializable`.
///
/// **Por qué existe:**
///
/// El backend NestJS usa TypeORM con PostgreSQL. Los campos `decimal` /
/// `numeric` de Postgres se serializan como **strings** en JSON
/// (`"7000.00"`) para preservar precisión (es el comportamiento por
/// defecto de `node-postgres`). El frontend Dart espera `double` →
/// crash:
///
/// ```
/// type 'String' is not a subtype of type 'num' in type cast
/// ```
///
/// **Cómo usar en los modelos:**
///
/// ```dart
/// @JsonKey(name: 'amount', fromJson: JsonParsers.parseDouble)
/// final double amount;
///
/// @JsonKey(name: 'received_amount', fromJson: JsonParsers.parseNullableDouble)
/// final double? receivedAmount;
/// ```
///
/// Después correr `dart run build_runner build --delete-conflicting-outputs`
/// para regenerar los `.g.dart`.
class JsonParsers {
  JsonParsers._();

  /// Convierte `String | num | null` a `double`. Si el valor es null o
  /// no se puede parsear, devuelve `0.0` (NO lanza — se queda con
  /// default seguro para no romper la pantalla por un mal dato).
  static double parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  /// Versión nullable: si viene `null` devuelve `null`, si no, parsea
  /// con la misma lógica.
  static double? parseNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  /// Convierte `String | num | null` a `int`. Trunca decimales si vienen.
  static int parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? 0;
    }
    return 0;
  }

  /// Versión nullable de `parseInt`.
  static int? parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value)?.toInt();
    }
    return null;
  }
}
