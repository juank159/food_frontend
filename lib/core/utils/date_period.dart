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

// Colombia (America/Bogotá) es siempre UTC-5, todo el año — no observa
// horario de verano. Mismo criterio que `DateTimeFormatter`.
const Duration _bogotaOffset = Duration(hours: -5);

/// [instant] (de cualquier reloj/zona) → sus campos año/mes/día tal
/// como se verían en un reloj de pared en Bogotá, **sin depender de la
/// zona horaria del dispositivo**. El objeto queda marcado UTC pero
/// sus campos representan hora de Bogotá (mismo truco que
/// `DateTimeFormatter._toBogota`) — se usa ACÁ solo para decidir qué
/// día calendario es "hoy" en Colombia, nunca para comparar instantes
/// directamente (para eso están `_bogotaMidnightUtc`/`_bogotaEndOfDayUtc`,
/// que sí devuelven instantes UTC reales).
DateTime _bogotaWallClock(DateTime instant) =>
    instant.toUtc().add(_bogotaOffset);

/// 00:00:00 del [y]-[m]-[d] EN BOGOTÁ, como instante UTC real
/// (medianoche Bogotá = 05:00 UTC del mismo día calendario).
DateTime _bogotaMidnightUtc(int y, int m, int d) => DateTime.utc(y, m, d, 5);

/// 23:59:59.999 del [y]-[m]-[d] EN BOGOTÁ, como instante UTC real.
DateTime _bogotaEndOfDayUtc(int y, int m, int d) =>
    // 28h en vez de 23:59:59.999 + 5h por separado: Dart normaliza el
    // overflow de horas solo, rodando al día siguiente 04:59:59.999 UTC
    // (que es, en Bogotá, las 23:59:59.999 del día [d]).
    DateTime.utc(y, m, d, 28, 59, 59, 999);

/// Traduce un [period] a un rango concreto cubriendo el día completo
/// (00:00:00 → 23:59:59.999) para que un filtro `created_at >= start AND
/// created_at <= end` no se pierda las órdenes de la tarde/noche.
///
/// **"Hoy"/"Ayer"/"7 días"/"Mes" se calculan SIEMPRE en hora de
/// Colombia (UTC-5 fija), nunca con la zona horaria ambiente del
/// dispositivo.** Bug real que esto corrige: un POS con el reloj o la
/// zona del sistema mal configurada (pasa más de lo que parece) hacía
/// que una venta hecha de noche quedara invisible en el filtro "Hoy" y
/// apareciera en cambio bajo "Ayer" — porque el cálculo de "qué día es
/// hoy" dependía de `DateTime.now()` del dispositivo en vez de la hora
/// real de Colombia. Mismo criterio que ya usa `DateTimeFormatter` para
/// mostrar horas — acá se aplica también para FILTRAR, no solo mostrar.
///
/// [now] es inyectable para tests; por defecto usa el instante actual.
///
/// El rango `custom` es la excepción a propósito: ahí el usuario elige
/// el día calendario a mano en un date picker (que ya muestra los días
/// en la zona del dispositivo), así que se respetan sus propios
/// año/mes/día tal cual — no se les aplica el ajuste de Bogotá.
DatePeriodRange resolveDatePeriod(
  DatePeriod period, {
  DateTime? customStart,
  DateTime? customEnd,
  DateTime? now,
}) {
  final today = _bogotaWallClock(now ?? DateTime.now());

  DateTime startOfBogotaDay(DateTime bogota) =>
      _bogotaMidnightUtc(bogota.year, bogota.month, bogota.day);
  DateTime endOfBogotaDay(DateTime bogota) =>
      _bogotaEndOfDayUtc(bogota.year, bogota.month, bogota.day);
  DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  switch (period) {
    case DatePeriod.today:
      return DatePeriodRange(startOfBogotaDay(today), endOfBogotaDay(today));
    case DatePeriod.yesterday:
      final y = today.subtract(const Duration(days: 1));
      return DatePeriodRange(startOfBogotaDay(y), endOfBogotaDay(y));
    case DatePeriod.last7Days:
      return DatePeriodRange(
        startOfBogotaDay(today.subtract(const Duration(days: 6))),
        endOfBogotaDay(today),
      );
    case DatePeriod.thisMonth:
      return DatePeriodRange(
        _bogotaMidnightUtc(today.year, today.month, 1),
        endOfBogotaDay(today),
      );
    case DatePeriod.all:
      return const DatePeriodRange(null, null);
    case DatePeriod.custom:
      return DatePeriodRange(
        customStart != null ? startOfDay(customStart) : null,
        customEnd != null ? endOfDay(customEnd) : null,
      );
  }
}
