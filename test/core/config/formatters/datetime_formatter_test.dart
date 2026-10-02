import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:menu_plat/core/config/formatters/datetime_formatter.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  group('DateTimeFormatter — siempre hora de Colombia, nunca del dispositivo',
      () {
    test('time12: convierte un instante UTC crudo del backend a Bogotá', () {
      // 2026-10-01 23:30 UTC = 2026-10-01 18:30 Bogotá (UTC-5) = 6:30 PM.
      final utcInstant = DateTime.utc(2026, 10, 1, 23, 30);
      expect(DateTimeFormatter.time12(utcInstant), '6:30 PM');
    });

    test(
        'time12: da el MISMO resultado sin importar si el caller ya hizo '
        '.toLocal() antes (bug real: antes esto rompía la hora)', () {
      final utcInstant = DateTime.utc(2026, 10, 1, 23, 30);
      // .toLocal() cambia el "tag" interno (isUtc=false) pero representa
      // el MISMO instante absoluto — time12() debe seguir dando 6:30 PM
      // sin importar qué zona tenga configurada la máquina que corre el
      // test, porque convierte vía `.toUtc()` adentro.
      final localTagged = utcInstant.toLocal();
      expect(DateTimeFormatter.time12(localTagged), '6:30 PM');
    });

    test('time12: medianoche Bogotá se muestra "12:00 AM", no "0:00"', () {
      // 05:00 UTC = 00:00 Bogotá.
      expect(DateTimeFormatter.time12(DateTime.utc(2026, 10, 1, 5, 0)),
          '12:00 AM');
    });

    test('time12: mediodía Bogotá se muestra "12:00 PM"', () {
      // 17:00 UTC = 12:00 Bogotá.
      expect(DateTimeFormatter.time12(DateTime.utc(2026, 10, 1, 17, 0)),
          '12:00 PM');
    });

    test('time12s: incluye segundos', () {
      expect(DateTimeFormatter.time12s(DateTime.utc(2026, 10, 1, 23, 30, 45)),
          '6:30:45 PM');
    });

    test('timeOnly: alias de time12, mismo resultado', () {
      final instant = DateTime.utc(2026, 10, 1, 14, 5);
      expect(DateTimeFormatter.timeOnly(instant),
          DateTimeFormatter.time12(instant));
    });

    test(
        'dateOnly: la fecha corresponde al día calendario de BOGOTÁ, no '
        'al de UTC (caso límite cerca de medianoche)', () {
      // 2026-10-02 02:00 UTC = 2026-10-01 21:00 Bogotá — todavía 1 de
      // octubre en Colombia, aunque en UTC ya sea 2 de octubre.
      final nearMidnightUtc = DateTime.utc(2026, 10, 2, 2, 0);
      expect(DateTimeFormatter.dateOnly(nearMidnightUtc), '01 oct 2026');
    });

    test('receiptDateTime: incluye fecha, hora 12h y la etiqueta de zona',
        () {
      final instant = DateTime.utc(2026, 10, 1, 23, 30, 0);
      final result = DateTimeFormatter.receiptDateTime(instant);
      expect(result, '01/10/2026 · 6:30:00 PM (hora Colombia)');
    });

    test(
        'isSameBogotaDay: dos instantes que son el mismo día en Bogotá '
        'pero días distintos en UTC', () {
      // 23:30 UTC del 1 de oct (6:30pm Bogotá, 1 oct) vs 02:00 UTC del 2
      // de oct (9:00pm Bogotá, TODAVÍA 1 de oct) — mismo día en Bogotá,
      // pero en UTC caen en fechas distintas.
      final a = DateTime.utc(2026, 10, 1, 23, 30);
      final b = DateTime.utc(2026, 10, 2, 2, 0);
      expect(DateTimeFormatter.isSameBogotaDay(a, b), isTrue);
    });

    test('isSameBogotaDay: false para días realmente distintos en Bogotá',
        () {
      final a = DateTime.utc(2026, 10, 1, 5, 0); // 00:00 Bogotá, 1 oct
      final b = DateTime.utc(2026, 10, 2, 4, 59); // 23:59 Bogotá, 1 oct... espera
      // Ajustamos b para que sea CLARAMENTE el día siguiente en Bogotá.
      final c = DateTime.utc(2026, 10, 2, 5, 0); // 00:00 Bogotá, 2 oct
      expect(DateTimeFormatter.isSameBogotaDay(a, b), isTrue);
      expect(DateTimeFormatter.isSameBogotaDay(a, c), isFalse);
    });

    test('bogotaDateOnly: normaliza a medianoche del día de Bogotá', () {
      final instant = DateTime.utc(2026, 10, 2, 2, 0); // 9pm Bogotá, 1 oct
      final result = DateTimeFormatter.bogotaDateOnly(instant);
      expect(result, DateTime(2026, 10, 1));
    });
  });
}
