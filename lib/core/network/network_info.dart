import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:internet_connection_checker/internet_connection_checker.dart';

/// Interfaz de chequeo de conectividad.
abstract class NetworkInfo {
  Future<bool> get isConnected;
}

/// En web no existe dart:io — siempre asumimos conectividad y dejamos
/// que Dio falle con su propio error si no hay red.
class _NetworkInfoWeb implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

/// Implementación real para mobile/desktop.
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

/// Factory: devuelve la implementación correcta según la plataforma.
NetworkInfo createNetworkInfo([InternetConnectionChecker? checker]) {
  if (kIsWeb) return _NetworkInfoWeb();
  return NetworkInfoImpl(checker);
}
