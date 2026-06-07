import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:internet_connection_checker/internet_connection_checker.dart';

/// Interfaz de chequeo de conectividad.
abstract class NetworkInfo {
  Future<bool> get isConnected;
}

/// Implementación real. Política:
///
///   - **Release:** verifica conectividad real con
///     `InternetConnectionChecker.hasConnection`. Si falla → `false`.
///     La UI ve "Sin conexión" y bloquea acciones que dependan del
///     backend.
///
///   - **Debug:** intenta verificar pero si falla devuelve `true` y
///     loggea un warning. Esto evita falsos negativos con localhost
///     (el checker pinga DNS públicos: si el dev está sin internet
///     pero el API local funciona, queremos que la app igual ande).
///
/// Timeout de 3s para que no bloquee el splash o pantallas iniciales.
class NetworkInfoImpl implements NetworkInfo {
  final InternetConnectionChecker connectionChecker;

  NetworkInfoImpl([InternetConnectionChecker? checker])
      : connectionChecker = checker ?? InternetConnectionChecker();

  @override
  Future<bool> get isConnected async {
    try {
      final connected = await connectionChecker.hasConnection
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      if (!connected && kDebugMode) {
        debugPrint(
          '[NetworkInfo] hasConnection=false en debug — '
          'asumiendo true (probablemente localhost / DNS público bloqueado)',
        );
        return true;
      }
      return connected;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NetworkInfo] check threw $e — asumiendo true en debug');
        return true;
      }
      return false;
    }
  }
}
