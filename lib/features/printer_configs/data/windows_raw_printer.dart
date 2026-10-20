// En web no existen `dart:ffi`/`win32` — cae al stub (siempre
// `isSupported == false`, así que `PrinterDispatcher` sigue el
// camino PDF existente ahí sin romper la compilación).
export 'windows_raw_printer_io.dart'
    if (dart.library.html) 'windows_raw_printer_stub.dart';
