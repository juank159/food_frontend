import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart';

/// Manda bytes ESC/POS crudos DIRECTO al spooler de Windows, sin pasar
/// por el renderizador GDI/PDF (que es lo que usa `Printing.layoutPdf`/
/// `directPrintPdf` del paquete `printing` — ESE camino es el que
/// obligaba a pedirle un PDF ya armado al backend).
///
/// **Por qué existe:** bug real reportado — las impresoras `system`
/// conectadas por USB en Windows dependían del backend para renderizar
/// un PDF, así que sin internet no imprimían nada, mientras que las de
/// `network` (que arman el ticket ESC/POS 100% local) sí funcionaban
/// sin internet. Windows expone cualquier impresora instalada (USB
/// incluida) a través del mismo spooler que una de red — `OpenPrinter`
/// + `StartDocPrinter` con `pDatatype: "RAW"` le pasa los bytes tal
/// cual al driver, exactamente como hace el socket TCP con una
/// impresora de red. Con esto, una impresora `system` con un printer
/// elegido (ver `printer_settings_screen.dart`) queda tan offline como
/// una de red: el ticket se arma local (mismo `EscPosGenerator`) y se
/// manda directo al hardware, sin tocar el backend para nada más que
/// el JSON de la orden (que YA necesitaba, igual que el camino de red).
///
/// Solo Windows — en otros SO (`Printer.url` ahí no es un nombre de
/// spooler Win32) sigue aplicando el camino PDF existente.
class WindowsRawPrinter {
  static bool get isSupported => !kIsWeb && Platform.isWindows;

  /// Manda [bytes] directo a la impresora Windows llamada
  /// [printerName] (el mismo string que `Printing.listPrinters()` da
  /// como `Printer.name`/`Printer.url` — en Windows son el mismo
  /// nombre real del spooler). Devuelve `false` si algo falla (la
  /// impresora se desconectó, el nombre ya no existe, etc.) — nunca
  /// lanza, para que el llamador pueda caer a un fallback.
  static bool printRawBytes({
    required String printerName,
    required Uint8List bytes,
  }) {
    if (!isSupported) return false;

    final phPrinter = calloc<IntPtr>();
    final pPrinterName = printerName.toNativeUtf16();
    final docInfo = calloc<DOC_INFO_1>();
    final pDocName = 'Ticket'.toNativeUtf16();
    final pDatatype = 'RAW'.toNativeUtf16();
    Pointer<Uint8>? pBuf;
    final pcWritten = calloc<Uint32>();

    try {
      if (OpenPrinter(pPrinterName, phPrinter, nullptr) == 0) {
        debugPrint('[WindowsRawPrinter] OpenPrinter falló para "$printerName"');
        return false;
      }
      final hPrinter = phPrinter.value;

      docInfo.ref
        ..pDocName = pDocName
        ..pOutputFile = nullptr
        ..pDatatype = pDatatype;

      final jobId = StartDocPrinter(hPrinter, 1, docInfo);
      if (jobId == 0) {
        debugPrint('[WindowsRawPrinter] StartDocPrinter falló');
        ClosePrinter(hPrinter);
        return false;
      }

      if (StartPagePrinter(hPrinter) == 0) {
        debugPrint('[WindowsRawPrinter] StartPagePrinter falló');
        EndDocPrinter(hPrinter);
        ClosePrinter(hPrinter);
        return false;
      }

      pBuf = calloc<Uint8>(bytes.length);
      pBuf.asTypedList(bytes.length).setAll(0, bytes);

      final wrote = WritePrinter(hPrinter, pBuf.cast(), bytes.length, pcWritten);

      EndPagePrinter(hPrinter);
      EndDocPrinter(hPrinter);
      ClosePrinter(hPrinter);

      if (wrote == 0 || pcWritten.value != bytes.length) {
        debugPrint(
          '[WindowsRawPrinter] WritePrinter incompleto: '
          '${pcWritten.value}/${bytes.length} bytes',
        );
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[WindowsRawPrinter] excepción: $e');
      return false;
    } finally {
      calloc.free(phPrinter);
      calloc.free(pPrinterName);
      calloc.free(docInfo);
      calloc.free(pDocName);
      calloc.free(pDatatype);
      calloc.free(pcWritten);
      if (pBuf != null) calloc.free(pBuf);
    }
  }
}
