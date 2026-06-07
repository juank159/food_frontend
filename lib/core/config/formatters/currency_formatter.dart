// lib/core/config/formatters/currency_formatter.dart
import 'package:intl/intl.dart';

/// CurrencyFormatter — formato de moneda colombiano (COP).
///
/// **Convención GARANTIZADA en TODA la app:**
///   - Símbolo `$` **siempre a la IZQUIERDA**, pegado al número (sin
///     espacio) → `$12.000`. NUNCA `12.000 $` ni `$ 12.000`.
///   - Punto `.` separa miles → `12.000`, `1.234.567`
///   - Coma `,` separa decimales → `12.000,50` (raro en COP, solo
///     cuando se usa `formatWithDecimals`)
///   - **Sin decimales por defecto** — el peso colombiano se redondea
///     a unidades enteras. Los precios en restaurantes / comercio van
///     como `$12.000`, NO `$12.000,00`.
///
/// **Importante:** usamos `NumberFormat` con `customPattern` explícito
/// en vez de `NumberFormat.currency(symbol:..., locale:...)` porque el
/// formato default de currency con `locale: 'es_CO'` puede meter
/// espacios o poner el símbolo al final dependiendo del paquete `intl`.
/// El patrón explícito `'¤#,##0'` garantiza símbolo izquierda
/// pegado al número, siempre.
///
/// **NUNCA escribas `'\$${X.toStringAsFixed(2)}'` ni `'$X'` literal en
/// código nuevo.** Usá siempre `CurrencyFormatter.format(X)` que ya
/// trae el `$` incluido.
class CurrencyFormatter {
  CurrencyFormatter._();

  /// Locale colombiano. Usado para los separadores de miles/decimales.
  static const String _locale = 'es_CO';

  /// Símbolo de moneda usado en TODA la app.
  static const String _symbol = '\$';

  /// Patrones explícitos: `¤` (U+00A4) es el placeholder de currency
  /// en `NumberFormat`, va al INICIO sin espacio antes del número.
  /// `customPattern` sobrescribe el patrón default del locale, así
  /// nos garantizamos que el símbolo SIEMPRE sale a la izquierda
  /// pegado al número (`$12.000`), sin importar el locale.
  static final NumberFormat _formatter = NumberFormat.currency(
    locale: _locale,
    symbol: _symbol,
    decimalDigits: 0,
    customPattern: '¤#,##0',
  );

  static final NumberFormat _formatterWithDecimals = NumberFormat.currency(
    locale: _locale,
    symbol: _symbol,
    decimalDigits: 2,
    customPattern: '¤#,##0.00',
  );

  static final NumberFormat _compactFormatter = NumberFormat.compactCurrency(
    symbol: _symbol,
    decimalDigits: 0,
    locale: _locale,
  );

  static final NumberFormat _noSymbolFormatter =
      NumberFormat('#,##0', _locale);

  /// Formato estándar de precio: `$12.000` (sin decimales, símbolo
  /// izquierda pegado, miles con punto). Usar en TODA la app para
  /// mostrar precios al usuario.
  ///
  /// Ejemplos:
  ///   - `12000` → `$12.000`
  ///   - `1234567` → `$1.234.567`
  ///   - `7000.5` → `$7.001` (se redondea — peso es entero)
  static String format(num amount) {
    return _formatter.format(amount);
  }

  /// Igual que `format` pero con 2 decimales. Usar SOLO cuando la
  /// precisión decimal sea relevante (ej. cálculo de IVA, conversiones).
  ///
  /// Ejemplo: `12345.67` → `$12.345,67`
  static String formatWithDecimals(num amount) {
    return _formatterWithDecimals.format(amount);
  }

  /// Versión compacta para totales muy grandes en dashboards.
  ///
  /// Ejemplo: `1234567` → `$1,2 M` (notación corta).
  static String formatCompact(num amount) {
    return _compactFormatter.format(amount);
  }

  /// Formato de número sin símbolo de moneda (para inputs / CSV / etc).
  ///
  /// Ejemplo: `12000` → `12.000`
  static String formatWithoutSymbol(num amount) {
    return _noSymbolFormatter.format(amount);
  }

  /// Parsea un string con formato colombiano a `double`.
  /// Acepta `12.000`, `12000`, `$12.000`, `12.000,50`, `12,5`.
  ///
  /// Devuelve `0.0` si el string es inválido (defensivo — nunca lanza).
  static double parse(String currencyString) {
    if (currencyString.trim().isEmpty) return 0.0;
    try {
      var s = currencyString.replaceAll(RegExp(r'[\$\s]'), '').trim();
      if (s.isEmpty) return 0.0;

      final hasComma = s.contains(',');
      final hasDot = s.contains('.');

      if (hasComma && hasDot) {
        // Formato CO completo: `12.345,67` → punto=miles, coma=decimal
        s = s.replaceAll('.', '').replaceAll(',', '.');
      } else if (hasComma) {
        // Solo coma: decimal `12,5` → `12.5`
        s = s.replaceAll(',', '.');
      } else if (hasDot) {
        // Solo puntos: puede ser miles (`12.000`) o decimal US (`12.5`).
        final dotCount = '.'.allMatches(s).length;
        if (dotCount > 1) {
          s = s.replaceAll('.', '');
        } else {
          final lastDot = s.lastIndexOf('.');
          final afterDot = s.length - lastDot - 1;
          if (afterDot == 3) {
            s = s.replaceAll('.', '');
          }
        }
      }

      return double.parse(s);
    } catch (e) {
      return 0.0;
    }
  }
}
