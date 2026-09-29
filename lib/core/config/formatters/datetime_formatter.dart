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

  /// `29/09/2026 · 2:27:36 PM (hora Colombia)` — fecha, hora y segundos
  /// completos, con la zona horaria explícita en el texto. Pensado para
  /// comparar un pago puntual contra el comprobante del banco, o para
  /// el ticket impreso de cierre de caja.
  ///
  /// **12 horas con AM/PM, nunca 24h ("hora militar")** — a propósito.
  /// Esta app la usa gente sin formación técnica; "14:27" es ambiguo
  /// para ese público, "2:27 PM" no. Mismo criterio que ya usa el
  /// ticket ESC/POS (`esc_pos_generator.dart` → `_hhmm`) — no se usa
  /// `DateFormat('...a', 'es')` porque el locale `es` imprime
  /// "p. m." (con puntos), más formal/confuso que el "PM" plano.
  static String receiptDateTime(DateTime dt) {
    final bog = _toBogota(dt);
    final date = DateFormat('dd/MM/yyyy', 'es').format(bog);
    return '$date · ${_time12(bog, seconds: true)} (hora Colombia)';
  }

  /// `29 sep 2026` — solo fecha, para encabezados.
  static String dateOnly(DateTime dt) =>
      DateFormat('dd MMM yyyy', 'es').format(_toBogota(dt));

  /// `2:27 PM` — solo hora (sin segundos, 12h con AM/PM), para listas
  /// compactas donde ya se sabe/muestra la fecha por separado.
  static String timeOnly(DateTime dt) =>
      _time12(_toBogota(dt), seconds: false);

  /// `2:27 PM` — igual que [timeOnly], pero a partir de un `DateTime`
  /// YA resuelto a la zona que quiera el caller (típicamente
  /// `.toLocal()`), sin forzar la conversión a Bogotá. Pensado como
  /// reemplazo directo de `DateFormat('HH:mm')` (24h / "hora militar")
  /// en toda la app — no todas las pantallas necesitan el rigor de
  /// zona horaria explícita de [receiptDateTime] (eso es solo para
  /// conciliar Bre-B contra el banco), pero TODAS necesitan mostrar la
  /// hora en 12h con AM/PM: esta app la usa gente sin formación
  /// técnica y "14:27" es ambiguo para ese público.
  static String time12(DateTime dt) => _time12(dt, seconds: false);

  /// `2:27:36 PM` — igual que [time12], pero con segundos.
  static String time12s(DateTime dt) => _time12(dt, seconds: true);

  static String _time12(DateTime bogota, {required bool seconds}) {
    final h = bogota.hour;
    final period = h < 12 ? 'AM' : 'PM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final mm = bogota.minute.toString().padLeft(2, '0');
    if (!seconds) return '$h12:$mm $period';
    final ss = bogota.second.toString().padLeft(2, '0');
    return '$h12:$mm:$ss $period';
  }
}
