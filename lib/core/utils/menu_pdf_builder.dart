import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../../features/categories/domain/entities/category.dart';
import '../../features/products/domain/entities/product.dart';

/// Genera el PDF de la carta completa del restaurante.
///
/// Incluye imágenes de los productos (descargadas de la URL),
/// precios, descripción y variantes. Usa `printing.networkImage`
/// para cargar imágenes desde URL con timeout graceful.
class MenuPdfBuilder {
  MenuPdfBuilder._();

  static final _cop = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
    customPattern: '¤#,##0',
  );

  static String _fmt(double v) => _cop.format(v);

  // Colores de la paleta editorial del menú QR
  static const _goldDark   = PdfColor.fromInt(0xFF8d6420);
  static const _goldLight  = PdfColor.fromInt(0xFFb8893e);
  static const _ink        = PdfColor.fromInt(0xFF2a1a08);
  static const _inkMuted   = PdfColor.fromInt(0xFF8a6a3a);
  static const _paper      = PdfColor.fromInt(0xFFf4e8cf);
  static const _leather    = PdfColor.fromInt(0xFF1f120a);

  /// Descarga la imagen de una URL con timeout.
  /// Devuelve null si falla (el producto se muestra sin imagen).
  static Future<pw.ImageProvider?> _fetchImage(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      return await networkImage(url).timeout(const Duration(seconds: 6));
    } catch (_) {
      return null;
    }
  }

  /// Construye el PDF y devuelve los bytes listos para compartir.
  ///
  /// [categories] y [products] se pasan desde la pantalla (ya cargados
  /// en memoria), así no se hace ningún request extra.
  static Future<List<int>> build({
    required List<Category> categories,
    required List<Product> products,
    String restaurantName = 'La Carta',
  }) async {
    // 1. Agrupar productos por categoría
    final Map<String, List<Product>> byCategory = {};
    for (final p in products) {
      byCategory.putIfAbsent(p.categoryId, () => []).add(p);
    }

    // Solo incluir categorías que tengan productos
    final activeCats = categories
        .where((c) => c.isActive && (byCategory[c.id]?.isNotEmpty ?? false))
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    // 2. Descargar todas las imágenes en paralelo
    final allProducts = activeCats.expand((c) => byCategory[c.id]!).toList();
    final imageMap = <String, pw.ImageProvider?>{};
    await Future.wait(
      allProducts.map((p) async {
        imageMap[p.id] = await _fetchImage(p.imageUrl);
      }),
    );

    // 3. Construir el PDF
    final pdf = pw.Document(
      title: restaurantName,
      author: 'Carta digital',
    );

    // Fuentes incluidas en el paquete pdf (sin descargas extra)
    final fontBold    = pw.Font.timesBold();
    final fontRegular = pw.Font.times();
    final fontHelv    = pw.Font.helvetica();
    final fontHelvB   = pw.Font.helveticaBold();

    final today = DateFormat("d 'de' MMMM 'de' y", 'es').format(DateTime.now());

    // ── Portada ────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        build: (ctx) => pw.Container(
          color: _leather,
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              // Línea superior decorativa
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 60),
                child: pw.Divider(color: _goldDark, thickness: 0.8),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'la',
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 28,
                  color: _goldLight,
                  fontStyle: pw.FontStyle.italic,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                restaurantName,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 54,
                  color: _paper,
                  letterSpacing: 2,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 12),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 120),
                child: pw.Divider(color: _goldDark, thickness: 0.6),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'CARTA DE PRECIOS',
                style: pw.TextStyle(
                  font: fontHelvB,
                  fontSize: 10,
                  color: _goldDark,
                  letterSpacing: 4,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                today,
                style: pw.TextStyle(
                  font: fontHelv,
                  fontSize: 9,
                  color: _inkMuted,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 20),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 60),
                child: pw.Divider(color: _goldDark, thickness: 0.8),
              ),
            ],
          ),
        ),
      ),
    );

    // ── Páginas de contenido ────────────────────────────────────────────
    final List<pw.Widget> contentWidgets = [];

    for (final cat in activeCats) {
      final prods = byCategory[cat.id] ?? [];

      // Encabezado de categoría
      contentWidgets.add(pw.SizedBox(height: 18));
      contentWidgets.add(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              cat.name.toUpperCase(),
              style: pw.TextStyle(
                font: fontHelvB,
                fontSize: 11,
                color: _goldDark,
                letterSpacing: 2.5,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Divider(color: _goldLight, thickness: 0.5),
          ],
        ),
      );
      contentWidgets.add(pw.SizedBox(height: 6));

      for (final product in prods) {
        final img = imageMap[product.id];
        final hasVariants = product.availableVariants.isNotEmpty;
        final priceLabel = hasVariants
            ? 'desde ${_fmt(product.minPrice)}'
            : _fmt(product.basePrice);

        contentWidgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Imagen del producto
                if (img != null) ...[
                  pw.ClipRRect(
                    horizontalRadius: 4,
                    verticalRadius: 4,
                    child: pw.Image(img, width: 68, height: 52, fit: pw.BoxFit.cover),
                  ),
                  pw.SizedBox(width: 10),
                ],

                // Info del producto
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Nombre + precio en la misma fila
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              product.name,
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 11,
                                color: _ink,
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text(
                            priceLabel,
                            style: pw.TextStyle(
                              font: fontHelvB,
                              fontSize: 11,
                              color: _goldDark,
                            ),
                          ),
                        ],
                      ),

                      // Descripción
                      if (product.description.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          product.description,
                          style: pw.TextStyle(
                            font: fontHelv,
                            fontSize: 8.5,
                            color: _inkMuted,
                          ),
                          maxLines: 2,
                          overflow: pw.TextOverflow.clip,
                        ),
                      ],

                      // Variantes
                      if (hasVariants) ...[
                        pw.SizedBox(height: 3),
                        ...product.availableVariants.map((v) {
                          final vPrice = product.basePrice + v.priceModifier;
                          return pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 1),
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  '  · ${v.name}',
                                  style: pw.TextStyle(
                                    font: fontHelv,
                                    fontSize: 8.5,
                                    color: _inkMuted,
                                  ),
                                ),
                                pw.Text(
                                  _fmt(vPrice),
                                  style: pw.TextStyle(
                                    font: fontHelv,
                                    fontSize: 8.5,
                                    color: _inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        // Separador fino entre productos
        contentWidgets.add(
          pw.Divider(color: PdfColors.grey300, thickness: 0.3),
        );
      }
    }

    // Pie de página
    contentWidgets.add(pw.SizedBox(height: 24));
    contentWidgets.add(pw.Center(
      child: pw.Text(
        'Precios en pesos colombianos (COP) · Sujetos a cambio sin previo aviso',
        style: pw.TextStyle(font: fontHelv, fontSize: 7.5, color: _inkMuted),
        textAlign: pw.TextAlign.center,
      ),
    ));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
        header: (ctx) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  restaurantName,
                  style: pw.TextStyle(font: fontBold, fontSize: 13, color: _ink),
                ),
                pw.Text(
                  'Carta de precios · ${ctx.pageNumber}/${ctx.pagesCount}',
                  style: pw.TextStyle(font: fontHelv, fontSize: 8, color: _inkMuted),
                ),
              ],
            ),
            pw.Divider(color: _goldDark, thickness: 0.5),
            pw.SizedBox(height: 4),
          ],
        ),
        build: (ctx) => contentWidgets,
      ),
    );

    return pdf.save();
  }
}
