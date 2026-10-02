import 'package:flutter_test/flutter_test.dart';
import 'package:menu_plat/core/utils/date_period.dart';

void main() {
  group('resolveDatePeriod — zona horaria Colombia (bug real reportado)', () {
    test(
        'today: los límites son medianoche-a-medianoche BOGOTÁ en UTC '
        'real, no UTC del dispositivo', () {
      // "Ahora" = 2 oct 2026, 02:00 UTC = 1 oct 2026, 21:00 Bogotá (9pm).
      // Si el cálculo usara el día UTC directo en vez de Bogotá, "hoy"
      // habría salido 2 de octubre — exactamente el bug reportado (una
      // venta de la noche quedaba fuera de "Hoy" y aparecía en "Ayer").
      final now = DateTime.utc(2026, 10, 2, 2, 0, 0);
      final range = resolveDatePeriod(DatePeriod.today, now: now);

      // Medianoche Bogotá del 1 de oct = 05:00 UTC del 1 de oct.
      expect(range.start, DateTime.utc(2026, 10, 1, 5, 0, 0));
      // 23:59:59.999 Bogotá del 1 de oct = 04:59:59.999 UTC del 2 de oct.
      expect(range.end, DateTime.utc(2026, 10, 2, 4, 59, 59, 999));
    });

    test(
        'una venta hecha a las 8:30pm Bogotá cae dentro de "hoy", nunca '
        'de "ayer"', () {
      // Caso real reportado por el usuario: venta de mesa 1/mesa 2 hecha
      // de noche, invisible en el filtro "Hoy" y visible en "Ayer".
      final now = DateTime.utc(2026, 10, 2, 2, 0, 0); // 9pm Bogotá, 1 oct
      final saleCreatedAt =
          DateTime.utc(2026, 10, 2, 1, 30, 0); // 8:30pm Bogotá, 1 oct

      final today = resolveDatePeriod(DatePeriod.today, now: now);
      final yesterday = resolveDatePeriod(DatePeriod.yesterday, now: now);

      bool withinRange(DateTime d, DatePeriodRange r) =>
          !d.isBefore(r.start!) && !d.isAfter(r.end!);

      expect(withinRange(saleCreatedAt, today), isTrue,
          reason: 'la venta debe caer dentro del rango de HOY');
      expect(withinRange(saleCreatedAt, yesterday), isFalse,
          reason: 'la venta NO debe caer en el rango de AYER');
    });

    test('yesterday: el día calendario anterior a hoy, en Bogotá', () {
      final now = DateTime.utc(2026, 10, 2, 2, 0, 0); // 1 oct en Bogotá
      final range = resolveDatePeriod(DatePeriod.yesterday, now: now);
      expect(range.start, DateTime.utc(2026, 9, 30, 5, 0, 0));
      expect(range.end, DateTime.utc(2026, 10, 1, 4, 59, 59, 999));
    });

    test('last7Days: desde 6 días antes de hoy (Bogotá) hasta hoy', () {
      final now = DateTime.utc(2026, 10, 2, 2, 0, 0); // 1 oct en Bogotá
      final range = resolveDatePeriod(DatePeriod.last7Days, now: now);
      expect(range.start, DateTime.utc(2026, 9, 25, 5, 0, 0));
      expect(range.end, DateTime.utc(2026, 10, 2, 4, 59, 59, 999));
    });

    test('thisMonth: desde el día 1 del mes (Bogotá) hasta hoy', () {
      final now = DateTime.utc(2026, 10, 2, 2, 0, 0); // 1 oct en Bogotá
      final range = resolveDatePeriod(DatePeriod.thisMonth, now: now);
      expect(range.start, DateTime.utc(2026, 10, 1, 5, 0, 0));
      expect(range.end, DateTime.utc(2026, 10, 2, 4, 59, 59, 999));
    });

    test('custom: respeta el año/mes/día elegido tal cual en el picker',
        () {
      final range = resolveDatePeriod(
        DatePeriod.custom,
        customStart: DateTime(2026, 5, 10),
        customEnd: DateTime(2026, 5, 12),
      );
      expect(range.start, DateTime(2026, 5, 10));
      expect(range.end, DateTime(2026, 5, 12, 23, 59, 59, 999));
    });

    test('all: sin límites', () {
      final range = resolveDatePeriod(DatePeriod.all);
      expect(range.start, isNull);
      expect(range.end, isNull);
    });
  });
}
