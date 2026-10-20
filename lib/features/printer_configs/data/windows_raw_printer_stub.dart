// Stub para Flutter Web — `dart:ffi`/`win32` no existen en el navegador.
// Mismo patrón que `core/stubs/io_stub.dart` para el socket TCP.
import 'dart:typed_data';

class WindowsRawPrinter {
  static bool get isSupported => false;

  static bool printRawBytes({
    required String printerName,
    required Uint8List bytes,
  }) {
    return false;
  }
}
