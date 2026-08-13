// Stubs de dart:io para la compilación web.
// Socket TCP no está disponible en navegador; estos stubs permiten compilar
// el código de impresión de red sin errores en web.

class OSError {
  final String message;
  final int errorCode;
  const OSError([this.message = '', this.errorCode = 0]);

  @override
  String toString() => 'OSError($errorCode): $message';
}

class Socket {
  static Future<Socket> connect(
    dynamic host,
    int port, {
    dynamic sourceAddress,
    int sourcePort = 0,
    Duration? timeout,
  }) async {
    throw UnsupportedError('Impresión de red no disponible en web');
  }

  void destroy() {}
  void add(List<int> data) {}
  Future<void> close() async {}
  Future<void> flush() async {}
}

class SocketException implements Exception {
  final String message;
  final OSError? osError;
  const SocketException(this.message, {this.osError});

  @override
  String toString() => 'SocketException: $message';
}
