// lib/core/utils/pdf_web_download_stub.dart
//
// Stub para plataformas nativas — en nativo nunca se llama a esto (el
// código de los call sites solo lo invoca cuando `kIsWeb` es true), pero
// tiene que existir y compilar para que el import condicional resuelva en
// esas plataformas.
import 'dart:typed_data';

void downloadBytesAsFile(Uint8List bytes, String filename) {
  throw UnsupportedError('downloadBytesAsFile solo está disponible en web');
}
