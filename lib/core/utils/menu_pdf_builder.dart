import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../config/formatters/currency_formatter.dart';
import '../../features/categories/domain/entities/category.dart';
import '../../features/products/domain/entities/product.dart';

class MenuPdfBuilder {
  MenuPdfBuilder._();

  static String _fmt(num v) => CurrencyFormatter.format(v);

  static const _goldDark  = PdfColor.fromInt(0xFF8d6420);
  static const _goldLight = PdfColor.fromInt(0xFFb8893e);
  static const _ink       = PdfColor.fromInt(0xFF2a1a08);
  static const _inkMuted  = PdfColor.fromInt(0xFF8a6a3a);
  static const _paper     = PdfColor.fromInt(0xFFf4e8cf);
  static const _leather   = PdfColor.fromInt(0xFF1f120a);

  // Tamaño fijo para TODAS las imágenes de producto — cuadrado uniforme.
  // BoxFit.cover recorta al centro: todas se ven iguales sin importar
  // si la foto original es vertical, horizontal o cuadrada.
  static const double _imgSize = 72;

  static Future<pw.ImageProvider?> _fetchImage(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      return await networkImage(url).timeout(const Duration(seconds: 8));
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List> build({
    required List<Category> categories,
    required List<Product> products,
    String restaurantName = 'Mi Restaurante',
    String? restaurantAddress,
    String? restaurantPhone,
    String? logoUrl,
  }) async {
    await initializeDateFormatting('es_CO', null);

    final Map<String, List<Product>> byCategory = {};
    for (final p in products) {
      byCategory.putIfAbsent(p.categoryId, () => []).add(p);
    }

    final activeCats = categories
        .where((c) => c.isActive && (byCategory[c.id]?.isNotEmpty ?? false))
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    final allProducts = activeCats.expand((c) => byCategory[c.id]!).toList();

    // Logo + imágenes de productos en paralelo
    final fetched = await Future.wait([
      _fetchImage(logoUrl),
      ...allProducts.map((p) => _fetchImage(p.imageUrl)),
    ]);

    final logoImg = fetched.first;
    final imageMap = <String, pw.ImageProvider?>{};
    for (var i = 0; i < allProducts.length; i++) {
      imageMap[allProducts[i].id] = fetched[i + 1];
    }

    final pdf = pw.Document(title: restaurantName, author: 'Carta digital');

    final fontBold  = pw.Font.timesBold();
    final fontHelv  = pw.Font.helvetica();
    final fontHelvB = pw.Font.helveticaBold();
    final fontItal  = pw.Font.timesItalic();

    final today = DateFormat("d 'de' MMMM 'de' y", 'es_CO').format(DateTime.now());

    // ── Portada ─────────────────────────────────────────────────────────────
    // Nombre del restaurante centrado, sin el "la" hardcodeado.
    // El nombre real del tenant se muestra completo y con buen tamaño.
    final nameFontSize = restaurantName.length > 24 ? 30.0
        : restaurantName.length > 16 ? 38.0
        : 48.0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Container(
          color: _leather,
          child: pw.Stack(
            children: [
              // Fondo decorativo: líneas horizontales tenues
              pw.Positioned.fill(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [pw.SizedBox()],
                ),
              ),
              // Contenido principal centrado
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 60),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      // Línea ornamental superior
                      _ornamentalLine(),
                      pw.SizedBox(height: 32),

                      // Logo (si existe)
                      if (logoImg != null) ...[
                        pw.ClipRRect(
                          horizontalRadius: 8,
                          verticalRadius: 8,
                          child: pw.Image(
                            logoImg,
                            width: 110,
                            height: 90,
                            fit: pw.BoxFit.contain,
                          ),
                        ),
                        pw.SizedBox(height: 24),
                      ],

                      // Etiqueta pequeña encima del nombre
                      pw.Text(
                        'CARTA DE PRECIOS',
                        style: pw.TextStyle(
                          font: fontHelvB,
                          fontSize: 9,
                          color: _goldLight,
                          letterSpacing: 4,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 10),

                      // Nombre del restaurante (dinámico, sin "la" hardcodeado)
                      pw.Text(
                        restaurantName,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: nameFontSize,
                          color: _paper,
                          letterSpacing: 1.5,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 16),

                      // Divider fino
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 40),
                        child: pw.Divider(color: _goldDark, thickness: 0.6),
                      ),
                      pw.SizedBox(height: 10),

                      // Fecha
                      pw.Text(
                        today,
                        style: pw.TextStyle(
                          font: fontItal,
                          fontSize: 10,
                          color: _inkMuted,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),

                      // Dirección y teléfono
                      if (restaurantAddress != null || restaurantPhone != null) ...[
                        pw.SizedBox(height: 14),
                        if (restaurantAddress != null)
                          pw.Text(
                            restaurantAddress,
                            style: pw.TextStyle(font: fontHelv, fontSize: 9, color: _inkMuted),
                            textAlign: pw.TextAlign.center,
                          ),
                        if (restaurantPhone != null)
                          pw.Text(
                            restaurantPhone,
                            style: pw.TextStyle(font: fontHelv, fontSize: 9, color: _inkMuted),
                            textAlign: pw.TextAlign.center,
                          ),
                      ],

                      pw.SizedBox(height: 32),
                      _ornamentalLine(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // ── Páginas de contenido ─────────────────────────────────────────────────
    final List<pw.Widget> content = [];

    for (final cat in activeCats) {
      final prods = byCategory[cat.id] ?? [];

      content.add(pw.SizedBox(height: 16));
      content.add(_categoryHeader(cat.name, fontHelvB));
      content.add(pw.SizedBox(height: 6));

      for (final product in prods) {
        final img = imageMap[product.id];
        final hasVariants = product.availableVariants.isNotEmpty;
        final priceLabel = hasVariants
            ? 'desde ${_fmt(product.minPrice)}'
            : _fmt(product.basePrice);

        content.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Imagen cuadrada uniforme — BoxFit.cover para que
                // todas ocupen exactamente _imgSize × _imgSize sin
                // importar el ratio original de la foto.
                pw.ClipRRect(
                  horizontalRadius: 5,
                  verticalRadius: 5,
                  child: pw.Container(
                    width: _imgSize,
                    height: _imgSize,
                    color: _paper,
                    child: img != null
                        ? pw.Image(img, fit: pw.BoxFit.cover)
                        : _imagePlaceholder(),
                  ),
                ),
                pw.SizedBox(width: 10),

                // Información del producto
                pw.Expanded(
                  child: pw.SizedBox(
                    height: _imgSize,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        // Nombre + precio en la misma fila
                        pw.Row(
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
                                maxLines: 2,
                              ),
                            ),
                            pw.SizedBox(width: 6),
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
                        if (product.description.trim().isNotEmpty) ...[
                          pw.SizedBox(height: 3),
                          pw.Text(
                            product.description.trim(),
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
                          ...product.availableVariants.take(3).map((v) {
                            final vPrice = product.basePrice + v.priceModifier;
                            return pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  '· ${v.name}',
                                  style: pw.TextStyle(font: fontHelv, fontSize: 8, color: _inkMuted),
                                ),
                                pw.Text(
                                  _fmt(vPrice),
                                  style: pw.TextStyle(font: fontHelv, fontSize: 8, color: _inkMuted),
                                ),
                              ],
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        content.add(pw.Divider(color: PdfColors.grey300, thickness: 0.3));
      }
    }

    // Pie de página
    content.add(pw.SizedBox(height: 20));
    content.add(pw.Center(
      child: pw.Text(
        'Precios en pesos colombianos (COP) · Sujetos a cambio sin previo aviso',
        style: pw.TextStyle(font: fontHelv, fontSize: 7.5, color: _inkMuted),
        textAlign: pw.TextAlign.center,
      ),
    ));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 32),
        header: (ctx) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  restaurantName,
                  style: pw.TextStyle(font: fontBold, fontSize: 12, color: _ink),
                ),
                pw.Text(
                  'Carta de precios  ·  ${ctx.pageNumber} / ${ctx.pagesCount}',
                  style: pw.TextStyle(font: fontHelv, fontSize: 8, color: _inkMuted),
                ),
              ],
            ),
            pw.Divider(color: _goldDark, thickness: 0.5),
            pw.SizedBox(height: 2),
          ],
        ),
        build: (ctx) => content,
      ),
    );

    return pdf.save();
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  static pw.Widget _ornamentalLine() => pw.Row(
        children: [
          pw.Expanded(child: pw.Divider(color: _goldDark, thickness: 0.6)),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            child: pw.Text(
              '✦',
              style: pw.TextStyle(
                font: pw.Font.helvetica(),
                fontSize: 8,
                color: _goldDark,
              ),
            ),
          ),
          pw.Expanded(child: pw.Divider(color: _goldDark, thickness: 0.6)),
        ],
      );

  static pw.Widget _categoryHeader(String name, pw.Font font) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            name.toUpperCase(),
            style: pw.TextStyle(
              font: font,
              fontSize: 10,
              color: _goldDark,
              letterSpacing: 2.5,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Divider(color: _goldLight, thickness: 0.5),
        ],
      );

  static pw.Widget _imagePlaceholder() => pw.Center(
        child: pw.Text(
          '?',
          style: pw.TextStyle(
            font: pw.Font.helvetica(),
            fontSize: 20,
            color: _inkMuted,
          ),
        ),
      );
}
