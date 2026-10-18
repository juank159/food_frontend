import 'dart:convert';

/// Lectura mínima y local del claim `exp` de un JWT — SIN validar
/// firma (eso es responsabilidad exclusiva del backend; esto es solo
/// para decidir, sin red, si vale la pena intentar usar un token).
///
/// Bug real reportado: la sesión "nunca se cerraba" porque nada
/// revisaba la expiración del `refresh_token` localmente — ver
/// `AuthRepositoryImpl.getCurrentUser`. `exp` es un claim estándar de
/// JWT (Unix timestamp en SEGUNDOS) y se puede leer decodificando el
/// payload en base64url, sin ningún request — por eso esta revisión
/// funciona igual con o sin internet.
class JwtUtils {
  JwtUtils._();

  /// `true` si el token ya expiró según su propio `exp`, o si no se
  /// pudo decodificar — más seguro tratar un token ilegible como
  /// expirado que como válido.
  static bool isExpired(String token) {
    final exp = expiryOf(token);
    if (exp == null) return true;
    return DateTime.now().isAfter(exp);
  }

  /// Fecha de expiración del token, o `null` si no se pudo leer.
  static DateTime? expiryOf(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map;
      final exp = payload['exp'];
      if (exp is! int) return null;
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    } catch (_) {
      return null;
    }
  }
}
