import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:menu_plat/core/utils/jwt_utils.dart';

/// Construye un JWT de prueba (header+payload+firma falsa) con el
/// `exp` que se le pida — no necesita ser válido criptográficamente,
/// `JwtUtils` nunca verifica la firma, solo lee el claim localmente.
String _fakeJwt(Map<String, dynamic> payload) {
  String encode(Map<String, dynamic> part) =>
      base64Url.encode(utf8.encode(jsonEncode(part))).replaceAll('=', '');
  final header = encode({'alg': 'HS256', 'typ': 'JWT'});
  final body = encode(payload);
  return '$header.$body.fake-signature';
}

void main() {
  group('JwtUtils.isExpired', () {
    test('false para un token con exp en el futuro', () {
      final token = _fakeJwt({
        'exp': DateTime.now()
                .add(const Duration(days: 1))
                .millisecondsSinceEpoch ~/
            1000,
      });
      expect(JwtUtils.isExpired(token), isFalse);
    });

    test('true para un token con exp en el pasado', () {
      final token = _fakeJwt({
        'exp': DateTime.now()
                .subtract(const Duration(days: 1))
                .millisecondsSinceEpoch ~/
            1000,
      });
      expect(JwtUtils.isExpired(token), isTrue);
    });

    test('true (fail-safe) si el token no tiene 3 partes', () {
      expect(JwtUtils.isExpired('no-es-un-jwt'), isTrue);
    });

    test('true (fail-safe) si el payload no es JSON válido', () {
      expect(JwtUtils.isExpired('aaa.bbb.ccc'), isTrue);
    });

    test('true (fail-safe) si el payload no tiene claim exp', () {
      final token = _fakeJwt({'sub': 'user-1'});
      expect(JwtUtils.isExpired(token), isTrue);
    });
  });

  group('JwtUtils.expiryOf', () {
    test('devuelve la fecha exacta del claim exp', () {
      final expSeconds =
          DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/
              1000;
      final token = _fakeJwt({'exp': expSeconds});
      final decoded = JwtUtils.expiryOf(token);
      expect(decoded, isNotNull);
      expect(decoded!.millisecondsSinceEpoch ~/ 1000, expSeconds);
    });

    test('devuelve null si no se puede decodificar', () {
      expect(JwtUtils.expiryOf('roto'), isNull);
    });
  });
}
