import 'package:flutter/foundation.dart';

/// Períodos rápidos reutilizables para filtros por fecha.
///
/// Pensado para usarse en CUALQUIER pantalla con filtro temporal
/// (órdenes, reportes, caja, etc.). La pantalla guarda el [DatePeriod]
/// seleccionado y lo traduce a un rango concreto con [resolveDatePeriod].
enum DatePeriod { today, yesterday, last7Days, thisMonth, all, custom }

extension DatePeriodLabel on DatePeriod {
  /// Etiqueta corta para el pill compacto del filtro.
  String get shortLabel {
    switch (this) {
      case DatePeriod.today:
        return 'Hoy';
      case DatePeriod.yesterday:
        return 'Ayer';
      case DatePeriod.last7Days:
        return '7 días';
      case DatePeriod.thisMonth:
        return 'Mes';
      case DatePeriod.all:
        return 'Todas';
      case DatePeriod.custom:
        return 'Rango';
    }
  }

  /// Etiqueta completa para menús y mensajes.
  String get label {
    switch (this) {
      case DatePeriod.today:
        return 'Hoy';
      case DatePeriod.yesterday:
        return 'Ayer';
      case DatePeriod.last7Days:
        return 'Últimos 7 días';
      case DatePeriod.thisMonth:
        return 'Este mes';
      case DatePeriod.all:
        return 'Todas';
      case DatePeriod.custom:
        return 'Rango personalizado';
    }
  }
}

/// Rango de fechas resuelto. `start`/`end` en `null` = sin límite (todo).
@immutable
class DatePeriodRange {
  final DateTime? start;
  final DateTime? end;
  const DatePeriodRange(this.start, this.end);
}

/// Traduce un [period] a un rango concreto cubriendo el día completo
/// (00:00:00 → 23:59:59.999) para que un filtro `created_at >= start AND
/// created_at <= end` no se pierda las órdenes de la tarde/noche.
///
/// [now] es inyectable para tests; por defecto usa la fecha actual.
DatePeriodRange resolveDatePeriod(
  DatePeriod period, {
  DateTime? customStart,
  DateTime? customEnd,
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  switch (period) {
    case DatePeriod.today:
      return DatePeriodRange(startOfDay(ref), endOfDay(ref));
    case DatePeriod.yesterday:
      final y = ref.subtract(const Duration(days: 1));
      return DatePeriodRange(startOfDay(y), endOfDay(y));
    case DatePeriod.last7Days:
      return DatePeriodRange(
        startOfDay(ref.subtract(const Duration(days: 6))),
        endOfDay(ref),
      );
    case DatePeriod.thisMonth:
      return DatePeriodRange(DateTime(ref.year, ref.month, 1), endOfDay(ref));
    case DatePeriod.all:
      return const DatePeriodRange(null, null);
    case DatePeriod.custom:
      return DatePeriodRange(
        customStart != null ? startOfDay(customStart) : null,
        customEnd != null ? endOfDay(customEnd) : null,
      );
  }
}
