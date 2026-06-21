// Smoke test placeholder.
//
// El boot completo de la app (`MenuPlatApp`) requiere que GetIt esté
// configurado vía `injection_container.init()` con todas las dependencias
// reales (Dio, secure storage, etc.). Eso es un test de integración que
// vive aparte de `flutter test` y necesita un backend disponible.
//
// Los tests reales de la app viven en `test/features/**` — entidades,
// modelos, controllers — sin depender del runtime completo.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanity check', () {
    expect(1 + 1, equals(2));
  });
}
