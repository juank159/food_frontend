// lib/core/config/formatters/datetime_formatter.dart
import 'package:intl/intl.dart';

/// DateTimeFormatter — fecha/hora SIEMPRE en horario de Colombia
/// (America/Bogotá), **independiente de cómo esté configurada la zona
/// horaria del dispositivo**.
///
/// **Por qué no usar `.toLocal()`:** eso confía en que el reloj/zona del
/// dispositivo esté bien puesto. Para conciliar un pago Bre-B/Nequi
/// contra el comprobante real del banco, la hora que se muestra tiene
/// que ser exacta — si el dispositivo tuviera mal la zona horaria (pasa
/// más de lo que parece), `.toLocal()` mostraría una hora distinta a la
/// del banco sin ningún aviso.
///
/// **Por qué no hace falta el paquete `timezone`:** Colombia (America/
/// Bogotá) es **siempre UTC-5, todo el año** — no observa horario de
/// verano. Restar 5 horas fijas al instante UTC es exacto siempre, sin
/// depender de una base de datos de zonas horarias.
class DateTimeFormatter {
  DateTimeFormatter._();

  static const Duration _bogotaOffset = Duration(hours: -5);

  /// Instante (en cualquier zona) → wall-clock de Bogotá.
  static DateTime _toBogota(DateTime dt) => dt.toUtc().add(_bogotaOffset);

  /// `29/09/2026 · 14:27:36 (hora Colombia)` — fecha, hora y segundos
  /// completos, con la zona horaria explícita en el texto. Pensado para
  /// comparar un pago puntual contra el comprobante del banco, o para
  /// el ticket impreso de cierre de caja.
  static String receiptDateTime(DateTime dt) {
    final bog = _toBogota(dt);
    final date = DateFormat('dd/MM/yyyy', 'es').format(bog);
    final time = DateFormat('HH:mm:ss', 'es').format(bog);
    return '$date · $time (hora Colombia)';
  }

  /// `29 sep 2026` — solo fecha, para encabezados.
  static String dateOnly(DateTime dt) =>
      DateFormat('dd MMM yyyy', 'es').format(_toBogota(dt));

  /// `14:27` — solo hora (sin segundos), para listas compactas donde ya
  /// se sabe/muestra la fecha por separado.
  static String timeOnly(DateTime dt) =>
      DateFormat('HH:mm', 'es').format(_toBogota(dt));
}
