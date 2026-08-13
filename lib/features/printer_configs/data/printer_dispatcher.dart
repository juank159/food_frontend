import 'dart:async';
import 'dart:io' if (dart.library.html) 'package:menu_plat/core/stubs/io_stub.dart';
import 'dart:typed_data';

import 'package:printing/printing.dart';

import 'models/printer_config_model.dart';

/// Despachador de impresión que decide cómo entregar el job según
/// la `PrinterConfigModel` elegida.
///
/// **Estrategias soportadas:**
///
/// 1. **`system`** → `printPdf`: usa `Printing.layoutPdf` y abre el
///    diálogo nativo del SO (CUPS / Windows / AirPrint). El SO se
///    encarga de rasterizar el PDF al driver de la impresora.
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
  /// Manda un PDF al diálogo nativo del SO (impresoras `system`).
  static Future<bool> printPdf({
    required Uint8List pdfBytes,
    String jobName = 'Ticket',
  }) {
    return _printViaSystem(pdfBytes, jobName);
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
