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
  /// compactas donde ya se sabe/muestra la fecha por separado. Alias de
  /// [time12] — mismo comportamiento, nombre distinto por legibilidad
  /// según el contexto de cada caller.
  static String timeOnly(DateTime dt) => time12(dt);

  /// `2:27 PM` — hora de Colombia en 12h con AM/PM, reemplazo directo de
  /// `DateFormat('HH:mm')` (24h / "hora militar") en toda la app.
  ///
  /// **SIEMPRE convierte a Bogotá primero** (vía `.toUtc()` + offset
  /// fijo), sin importar si [dt] llega en UTC crudo del backend o ya
  /// pasó por `.toLocal()` en el caller — en cualquiera de los dos
  /// casos, `.toUtc()` adentro de esta función deshace correctamente lo
  /// que haga falta y vuelve a aplicar el offset de Bogotá. Antes NO
  /// convertía nada (leía `.hour`/`.minute` directo de lo que llegara),
  /// lo cual, mezclado con un `.toLocal()` previo del dispositivo,
  /// terminaba mostrando la hora LOCAL del dispositivo en vez de la de
  /// Colombia — bug real encontrado en ~20 lugares de la app (pagos,
  /// órdenes, cuentas abiertas, turnos, caja, reportes) que confiaban
  /// en que el dispositivo tuviera la zona horaria bien puesta.
  ///
  /// Si tenés un `DateTime` que NO es un instante guardado sino un
  /// valor que la persona ACABA de elegir en un time picker (todavía no
  /// se guardó en ningún lado), NO uses esto — reformateá sus propios
  /// `hour`/`minute` a 12h directo, sin pasar por acá (convertir ese
  /// valor a Bogotá mostraría una hora distinta a la que ve en el
  /// picker nativo). Ver `reservation_form_page.dart`/`_format12h` para
  /// el patrón correcto en ese caso.
  static String time12(DateTime dt) => _time12(_toBogota(dt), seconds: false);

  /// `2:27:36 PM` — igual que [time12], pero con segundos.
  static String time12s(DateTime dt) =>
      _time12(_toBogota(dt), seconds: true);

  static String _time12(DateTime bogota, {required bool seconds}) {
    final h = bogota.hour;
    final period = h < 12 ? 'AM' : 'PM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final mm = bogota.minute.toString().padLeft(2, '0');
    if (!seconds) return '$h12:$mm $period';
    final ss = bogota.second.toString().padLeft(2, '0');
    return '$h12:$mm:$ss $period';
  }

  /// "Ahora", pero en hora de pared de Bogotá — **sin depender de la
  /// zona horaria del dispositivo**. Reemplazo directo de
  /// `DateTime.now()` en CUALQUIER lugar que decida "¿esto es hoy?",
  /// "¿ya venció?", "¿cuántos días faltan?" sobre un instante guardado
  /// (reservas, turnos, caja, clientes, menú del día, KPIs del
  /// dashboard...). Bug real que esto corrige: con el reloj/zona del
  /// dispositivo mal puesta, una reserva/venta de la noche se
  /// clasificaba como "de mañana" o "de ayer" según la pantalla —
  /// encontrado duplicado en más de 15 lugares de la app, cada uno
  /// reimplementando `DateTime.now()` por su cuenta.
  static DateTime nowInBogota() => _toBogota(DateTime.now());

  /// `true` si [a] y [b] caen en el MISMO día calendario en Bogotá —
  /// sin importar si llegan en UTC crudo, `.toLocal()`'d, o ya
  /// resueltos a Bogotá. Reemplazo directo de comparar
  /// `a.year==b.year && a.month==b.month && a.day==b.day` a mano, que
  /// es exactamente donde vivía el bug (esos campos reflejan la zona
  /// que tenga CADA DateTime por separado, no necesariamente Bogotá).
  static bool isSameBogotaDay(DateTime a, DateTime b) {
    final ba = _toBogota(a);
    final bb = _toBogota(b);
    return ba.year == bb.year && ba.month == bb.month && ba.day == bb.day;
  }

  /// Día calendario de Bogotá para [dt], como `DateTime` normalizado a
  /// medianoche (año/mes/día nada más) — útil para restar días y sacar
  /// "hace cuántos días" sin que la hora del día meta ruido.
  static DateTime bogotaDateOnly(DateTime dt) {
    final b = _toBogota(dt);
    return DateTime(b.year, b.month, b.day);
  }
}
