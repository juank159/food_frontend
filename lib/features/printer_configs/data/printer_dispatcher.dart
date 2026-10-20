import 'dart:async';
import 'dart:io' if (dart.library.html) 'package:menu_plat/core/stubs/io_stub.dart';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'models/printer_config_model.dart';

/// Despachador de impresión que decide cómo entregar el job según
/// la `PrinterConfigModel` elegida.
///
/// **Estrategias soportadas:**
///
/// 1. **`system`** → `printPdf`: si el admin eligió una impresora
///    instalada en Configuración (ver `listInstalledPrinters`), manda
///    el PDF DIRECTO con `Printing.directPrintPdf` — sin diálogo. Si
///    no eligió ninguna (o ya no está disponible), cae al diálogo
///    nativo del SO (CUPS / Windows / AirPrint) vía `Printing.layoutPdf`.
///
/// 2. **`network`** → `printRawBytes`: abre socket TCP raw a
///    `host:port` (default 9100) y manda el stream ESC/POS ya
///    generado por `EscPosGenerator`. Las térmicas (Epson TM,
///    Bixolon, Xprinter, Star) **no entienden PDF en el puerto
///    raw** — si les mandás un PDF imprimen caracteres random y
///    desperdician metros de papel. Por eso este path acepta bytes
///    ESC/POS crudos, no PDF.
///
/// **Timeout corto** (10s) para que la app no quede colgada si la
/// impresora está apagada o cambió de IP.
class PrinterDispatcher {
  /// Manda un PDF a una impresora `system`.
  ///
  /// Si `printerUrl` viene con un valor (el admin eligió una impresora
  /// instalada en Configuración → Impresoras) y esa impresora sigue
  /// disponible, imprime DIRECTO con `Printing.directPrintPdf` — sin
  /// diálogo, sin confirmación manual. Si no se eligió ninguna, o la
  /// que se eligió ya no está conectada/instalada, cae al diálogo
  /// nativo del SO (`Printing.layoutPdf`) — nunca deja al usuario sin
  /// poder imprimir solo porque la impresora guardada desapareció.
  static Future<bool> printPdf({
    required Uint8List pdfBytes,
    String jobName = 'Ticket',
    String? printerUrl,
  }) async {
    if (printerUrl != null && printerUrl.isNotEmpty) {
      final direct = await _printDirectToSaved(pdfBytes, jobName, printerUrl);
      if (direct != null) return direct;
    }
    return _printViaSystem(pdfBytes, jobName);
  }

  /// Busca la impresora guardada entre las instaladas (por `url`, el
  /// identificador único que da el SO) y le manda el PDF directo, sin
  /// diálogo. Devuelve `null` (no `false`) si la impresora ya no está
  /// disponible — así `printPdf` sabe que debe caer al diálogo en vez
  /// de reportar un error real de impresión.
  static Future<bool?> _printDirectToSaved(
    Uint8List pdfBytes,
    String jobName,
    String printerUrl,
  ) async {
    try {
      final printers = await Printing.listPrinters();
      final match = printers
          .where((p) => p.url == printerUrl && p.isAvailable)
          .firstOrNull;
      if (match == null) return null;
      return await Future.value(Printing.directPrintPdf(
        printer: match,
        onLayout: (_) async => pdfBytes,
        name: jobName,
      )).timeout(const Duration(seconds: 60), onTimeout: () => false);
    } catch (_) {
      return null;
    }
  }

  /// Lista las impresoras instaladas en el sistema operativo (las que
  /// se ven en el panel de impresoras de Windows/macOS/Linux, incluidas
  /// las conectadas por USB — Windows las expone igual que una de red
  /// una vez que el driver está instalado). Usado por la pantalla de
  /// Configuración → Impresoras para elegir una en vez de depender del
  /// diálogo del SO en cada impresión. No soportado en Flutter Web
  /// (sandbox del navegador no tiene acceso al listado del SO).
  static Future<List<Printer>> listInstalledPrinters() async {
    try {
      return await Printing.listPrinters();
    } catch (_) {
      return const [];
    }
  }

  /// Imprime una página de prueba DIRECTO a la impresora elegida (sin
  /// diálogo) — para que el admin confirme que la elección fue
  /// correcta antes de guardarla.
  static Future<bool> testSystemPrinter(Printer printer) async {
    try {
      final pdf = await _buildTestPdf();
      return await Future.value(Printing.directPrintPdf(
        printer: printer,
        onLayout: (_) async => pdf,
        name: 'Prueba de impresora',
      )).timeout(const Duration(seconds: 30), onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }

  static Future<Uint8List> _buildTestPdf() async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (_) => pw.Padding(
          padding: const pw.EdgeInsets.all(12),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'Prueba de impresora',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Si ves esto impreso, la impresora elegida funciona.',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
    return doc.save();
  }

  /// Manda bytes crudos (ESC/POS) por socket TCP a una impresora de red.
  static Future<bool> printRawBytes({
    required Uint8List bytes,
    required PrinterConfigModel printer,
  }) {
    return _printViaNetwork(
      bytes,
      host: printer.host ?? '',
      port: printer.port ?? 9100,
    );
  }

  // ─── Sistema (diálogo nativo del SO) ──────────────────────────────

  static Future<bool> _printViaSystem(
    Uint8List pdfBytes,
    String jobName,
  ) async {
    try {
      return await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: jobName,
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    }
  }

  // ─── Network TCP raw a IP:9100 ────────────────────────────────────

  static Future<bool> _printViaNetwork(
    Uint8List rawBytes, {
    required String host,
    required int port,
  }) async {
    if (host.trim().isEmpty) {
      throw Exception('Impresora de red sin IP configurada');
    }
    Socket? socket;
    try {
      socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 10),
      ).timeout(const Duration(seconds: 10));
      socket.add(rawBytes);
      await socket.flush();
      // Pequeño delay para que la impresora termine de bufferear
      // antes de cerrar el socket. Sin esto algunos modelos cortan
      // el último cm del ticket.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return true;
    } catch (e) {
      rethrow;
    } finally {
      try {
        await socket?.close();
      } catch (_) {}
    }
  }

  /// Ping rápido a la impresora de red. Versión legacy bool — usar
  /// `diagnoseNetworkConnection` para diagnóstico detallado.
  static Future<bool> testNetworkConnection({
    required String host,
    required int port,
  }) async {
    final result = await diagnoseNetworkConnection(host: host, port: port);
    return result.ok;
  }

  /// Diagnóstico detallado de conexión TCP a la impresora.
  ///
  /// Devuelve un `ConnectionDiagnosis` con el resultado y una pista
  /// human-friendly sobre qué hacer si falla. Esto reemplaza al
  /// mensaje genérico "inalcanzable" que no ayudaba al usuario a
  /// entender si era un problema de red, IP errónea, impresora
  /// apagada o subnet distinta.
  static Future<ConnectionDiagnosis> diagnoseNetworkConnection({
    required String host,
    required int port,
  }) async {
    Socket? s;
    try {
      s = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );
      return ConnectionDiagnosis.ok(host: host, port: port);
    } on SocketException catch (e) {
      // OS error code revela la causa real.
      final code = e.osError?.errorCode;
      final msg = (e.osError?.message ?? e.message).toLowerCase();
      String hint;

      if (msg.contains('refused') || code == 61 /* macOS ECONNREFUSED */) {
        hint =
            'La IP $host responde pero el puerto $port está cerrado. '
            'Asegurate que la impresora tenga "Raw Print" habilitado '
            '(puerto 9100). En algunas Epson hay que activarlo en el '
            'menú de configuración de red.';
      } else if (msg.contains('timed out') ||
          msg.contains('timeout') ||
          code == 60 /* ETIMEDOUT */) {
        hint =
            'No hubo respuesta de $host. Verificá:\n'
            '• La impresora está encendida\n'
            '• Está en la misma red WiFi/cable que esta computadora\n'
            '• La IP es correcta (imprimí el self-test de la impresora '
            'para ver su IP actual — el DHCP la puede haber cambiado)';
      } else if (msg.contains('no route') ||
          msg.contains('network is unreachable') ||
          code == 51 /* ENETUNREACH */) {
        hint =
            'No hay ruta a $host. Tu computadora y la impresora están '
            'en redes distintas. Verificá la subred (ej. tu Mac está en '
            '192.168.0.x pero la impresora en 192.168.1.x).';
      } else if (msg.contains('host')) {
        hint =
            'No se pudo resolver $host. Si pusiste un nombre, probá '
            'con la IP directa (ej. 192.168.1.50).';
      } else {
        hint =
            'Error de red: ${e.osError?.message ?? e.message}. '
            'Revisá conectividad y firewall.';
      }

      return ConnectionDiagnosis.fail(
        host: host,
        port: port,
        rawError: e.toString(),
        hint: hint,
      );
    } catch (e) {
      return ConnectionDiagnosis.fail(
        host: host,
        port: port,
        rawError: e.toString(),
        hint: 'Error inesperado: $e',
      );
    } finally {
      try {
        await s?.close();
      } catch (_) {}
    }
  }
}

/// Resultado detallado de un test de conexión TCP.
class ConnectionDiagnosis {
  final bool ok;
  final String host;
  final int port;
  final String? rawError;
  final String? hint;

  const ConnectionDiagnosis._({
    required this.ok,
    required this.host,
    required this.port,
    this.rawError,
    this.hint,
  });

  factory ConnectionDiagnosis.ok({
    required String host,
    required int port,
  }) =>
      ConnectionDiagnosis._(ok: true, host: host, port: port);

  factory ConnectionDiagnosis.fail({
    required String host,
    required int port,
    required String rawError,
    required String hint,
  }) =>
      ConnectionDiagnosis._(
        ok: false,
        host: host,
        port: port,
        rawError: rawError,
        hint: hint,
      );
}
