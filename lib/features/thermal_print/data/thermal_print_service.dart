import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:printing/printing.dart';

import '../../../core/config/constants/api_constants.dart';

/// Ancho de papel térmico POS soportado.
enum ThermalPaperWidth {
  mm80('80', '80 mm'),
  mm58('58', '58 mm');

  final String apiValue;
  final String displayName;

  const ThermalPaperWidth(this.apiValue, this.displayName);
}

/// Cliente Flutter para los endpoints de impresión térmica del backend.
///
/// **Flujo:**
///   1. Pide el PDF al backend (con `?width=80|58`).
///   2. Lanza el dialog nativo de impresión del SO con ese PDF.
///   3. El usuario elige la impresora térmica conectada y confirma.
///
/// **Por qué no genera el PDF en el cliente:** mantiene los layouts
/// del recibo / comanda / QR en un solo lugar (backend). Si cambia
/// el formato (logo nuevo, columna extra), basta deploy backend —
/// no hay que actualizar la app.
///
/// **Si el SO no soporta `printing.layoutPdf`** (raro, principalmente
/// algunas configuraciones Linux), el helper `downloadAsPdf` permite
/// descargar el PDF para imprimirlo desde el visor.
class ThermalPrintService {
  ThermalPrintService({required this.dio});

  final Dio dio;

  /// Imprime el PDF del QR de un token (admin pega en mesa).
  Future<bool> printQrToken({
    required String code,
    ThermalPaperWidth width = ThermalPaperWidth.mm80,
  }) async {
    final pdf = await _fetchPdf(
      path: '${ApiConstants.qrPrintBase}/$code/thermal',
      width: width,
    );
    return _launchPrint(pdf, name: 'QR $code (${width.displayName})');
  }

  /// Imprime el recibo del cliente.
  Future<bool> printReceipt({
    required String orderId,
    ThermalPaperWidth width = ThermalPaperWidth.mm80,
  }) async {
    final pdf = await _fetchPdf(
      path: '/orders/$orderId/print/receipt',
      width: width,
    );
    return _launchPrint(pdf, name: 'Recibo (${width.displayName})');
  }

  /// Imprime la comanda de cocina (sin precios).
  Future<bool> printKitchenTicket({
    required String orderId,
    ThermalPaperWidth width = ThermalPaperWidth.mm80,
  }) async {
    final pdf = await _fetchPdf(
      path: '/orders/$orderId/print/kitchen',
      width: width,
    );
    return _launchPrint(pdf, name: 'Comanda (${width.displayName})');
  }

  /// Descarga el PDF sin imprimirlo (para preview en pantalla o
  /// guardar/compartir).
  Future<Uint8List> getReceiptPdfBytes({
    required String orderId,
    ThermalPaperWidth width = ThermalPaperWidth.mm80,
  }) {
    return _fetchPdf(
      path: '/orders/$orderId/print/receipt',
      width: width,
    );
  }

  Future<Uint8List> getKitchenPdfBytes({
    required String orderId,
    ThermalPaperWidth width = ThermalPaperWidth.mm80,
  }) {
    return _fetchPdf(
      path: '/orders/$orderId/print/kitchen',
      width: width,
    );
  }

  Future<Uint8List> getQrPdfBytes({
    required String code,
    ThermalPaperWidth width = ThermalPaperWidth.mm80,
  }) {
    return _fetchPdf(
      path: '${ApiConstants.qrPrintBase}/$code/thermal',
      width: width,
    );
  }

  /// Pide el PDF A4 con varios QRs en grilla y lo imprime.
  /// perPage=1 → un QR enorme por hoja (ideal sticker individual).
  Future<bool> printQrSheet({
    required List<String> codes,
    int perPage = 4,
  }) async {
    final pdfBytes = await getQrSheetBytes(codes: codes, perPage: perPage);
    return Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: 'QRs (${codes.length} en hoja A4)',
    );
  }

  /// Descarga los bytes del PDF sheet sin imprimir — para mostrar
  /// vista previa en pantalla con `PdfPreview`.
  Future<Uint8List> getQrSheetBytes({
    required List<String> codes,
    int perPage = 4,
  }) async {
    final response = await dio.post<List<int>>(
      '${ApiConstants.qrTokens}/print/sheet',
      data: {'codes': codes, 'per_page': perPage},
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': 'application/pdf'},
      ),
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw Exception('PDF vacío recibido del servidor');
    }
    return Uint8List.fromList(data);
  }

  // -------------------------------------------------------------------

  Future<Uint8List> _fetchPdf({
    required String path,
    required ThermalPaperWidth width,
  }) async {
    final response = await dio.get<List<int>>(
      path,
      queryParameters: {'width': width.apiValue},
      options: Options(
        responseType: ResponseType.bytes,
        // Acepta PDF binario, no JSON.
        headers: {'Accept': 'application/pdf'},
      ),
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw Exception('PDF vacío recibido del servidor');
    }
    return Uint8List.fromList(data);
  }

  /// Lanza el dialog nativo de impresión. Retorna `true` si el usuario
  /// confirmó, `false` si canceló.
  Future<bool> _launchPrint(Uint8List pdfBytes, {required String name}) {
    return Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: name,
      // `format: null` deja que el SO use el tamaño que ya trae el PDF
      // (los nuestros vienen con dimensiones exactas 80mm o 58mm).
    );
  }
}
