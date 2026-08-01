import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;

import '../../../core/config/formatters/currency_formatter.dart';

/// Datos que necesitamos para imprimir un ticket.
/// El frontend los arma desde la `Order` ya cargada en memoria
/// (no pedimos otro GET — los datos ya viajaron en el approve response).
class TicketData {
  // ── Negocio ──
  final String businessName;
  final String? address;
  final String? phone;
  final String? taxId;

  /// Bytes crudos del logo (PNG/JPG ya descargado). Solo se imprime en
  /// el recibo, centrado arriba del nombre. `null` = sin logo. El
  /// orquestador lo descarga (con cache) desde `settings.receipt.logo_url`.
  final Uint8List? logoBytes;

  // ── Orden ──
  final String orderNumber;
  final DateTime createdAt;
  final String? tableLabel;
  final String orderType; // dine_in / takeaway / delivery
  final String orderSource; // pos / qr_self_order

  // ── Cliente ──
  final String? customerName;
  final String? customerPhone;

  // ── Items ──
  final List<TicketItem> items;

  // ── Totales (solo para recibo) ──
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double tipAmount;
  final double totalAmount;
  final String? paymentMethod;

  // ── Footer ──
  final String? notes;

  const TicketData({
    required this.businessName,
    required this.address,
    required this.phone,
    required this.taxId,
    this.logoBytes,
    required this.orderNumber,
    required this.createdAt,
    required this.tableLabel,
    required this.orderType,
    required this.orderSource,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.tipAmount,
    required this.totalAmount,
    required this.paymentMethod,
    required this.notes,
  });
}

class TicketItem {
  final int quantity;
  final String name;
  final String? variantName;
  final double unitPrice;
  final double subtotal;
  final String? specialInstructions;
  /// `true` si el producto va a cocina/barra. La comanda solo lista
  /// los items con `true`; el recibo lista TODOS. Default `true` por
  /// seguridad (productos sin flag explícito siguen yendo a cocina).
  final bool requiresPreparation;

  /// Categoría del producto — la comanda se agrupa por categoría e
  /// imprime un ticket separado por cada una.
  final String? categoryName;

  /// Si la categoría imprime comanda. Items en `false` no salen a cocina
  /// aunque `requiresPreparation` sea true. Default `true`.
  final bool categoryPrintsKitchen;

  /// Cremas/sabores elegidos (uno por bola) — se imprimen en la comanda.
  final List<String> selectedFlavors;

  const TicketItem({
    required this.quantity,
    required this.name,
    required this.variantName,
    required this.unitPrice,
    required this.subtotal,
    required this.specialInstructions,
    this.requiresPreparation = true,
    this.categoryName,
    this.categoryPrintsKitchen = true,
    this.selectedFlavors = const [],
  });
}

/// Generador de ESC/POS para impresoras térmicas POS de red.
///
/// **Por qué este archivo existe:**
/// Las térmicas (Epson TM, Bixolon, Xprinter, Star, etc.) escuchan
/// en TCP:9100 esperando bytes ESC/POS — un protocolo binario donde
/// `0x1B 0x40` significa "init", `0x1B 0x61 0x01` "centrar", etc.
/// Mandarles un PDF como hacíamos antes hace que interpreten cada
/// byte literalmente, salgan caracteres random y desperdicien papel.
///
/// Este generador toma `TicketData` (plain Dart) y produce
/// `Uint8List` con los bytes ESC/POS correctos según el ancho del
/// papel (58mm = 32 chars, 80mm = 48 chars).
class EscPosGenerator {
  EscPosGenerator._();

  /// Genera comanda de cocina (sin precios, fuente grande, foco en
  /// cantidad + nombre + notas).
  static Future<Uint8List> buildKitchen({
    required TicketData data,
    required int paperWidthMm, // 58 | 80
  }) async {
    final profile = await CapabilityProfile.load();
    final paper = paperWidthMm == 58 ? PaperSize.mm58 : PaperSize.mm80;
    final gen = Generator(paper, profile);

    final bytes = <int>[];
    bytes.addAll(gen.reset());
    // NO cambiamos la página de código: la impresora queda en su CP437 nativo.
    // _sanitize() convierte los caracteres españoles al byte CP437 correcto
    // antes de que el codec latin1 los envíe (ñ→0xA4, Ñ→0xA5, á→0xA0…).

    // Items que VAN a cocina/barra: requieren preparación Y su categoría
    // imprime comanda. Lo demás (botellas, snacks, categorías excluidas)
    // no aparece — sale en el recibo pero no en cocina.
    final kitchenItems = data.items
        .where((i) => i.requiresPreparation && i.categoryPrintsKitchen)
        .toList();
    if (kitchenItems.isEmpty) {
      return Uint8List.fromList(bytes);
    }

    // Agrupar por categoría preservando el orden de aparición → una
    // comanda SEPARADA (con su propio corte) por cada categoría.
    final groups = <String, List<TicketItem>>{};
    for (final item in kitchenItems) {
      final key = (item.categoryName ?? 'GENERAL').toUpperCase();
      groups.putIfAbsent(key, () => []).add(item);
    }

    for (final entry in groups.entries) {
      _writeKitchenSection(gen, bytes, data, entry.key, entry.value);
    }

    return Uint8List.fromList(bytes);
  }

  /// Escribe UNA comanda (la de una categoría) en [bytes], terminando con
  /// corte de papel para que cada categoría salga en su propio ticket.
  static void _writeKitchenSection(
    Generator gen,
    List<int> bytes,
    TicketData data,
    String categoryName,
    List<TicketItem> items,
  ) {
    // ─── Header: "COMANDA" + categoría (estación) + tipo de orden ───
    // "COMANDA" en tamaño normal (es solo la etiqueta); la categoría
    // (estación) y el destino se mantienen grandes y legibles. Ahorra papel.
    bytes.addAll(
      gen.text(
        'COMANDA',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    bytes.addAll(
      gen.text(
        _sanitize(categoryName),
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          bold: true,
        ),
      ),
    );

    // ─── Destino (GRANDE) ───
    final destination = _destinationLabel(data);
    bytes.addAll(
      gen.text(
        destination,
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size3,
          width: PosTextSize.size2,
          bold: true,
        ),
      ),
    );

    // ─── Nombre del cliente (justo bajo el destino) ───
    // Para pedidos QR siempre lo imprimimos en tamaño grande para que
    // el mesero identifique al cliente de un vistazo. Para pedidos del
    // POS lo imprimimos solo si difiere del destino (evita repetir
    // "Mostrador / Mostrador").
    final hasCustomer = data.customerName != null &&
        data.customerName!.trim().isNotEmpty &&
        data.customerName!.trim() != destination;
    if (hasCustomer) {
      bytes.addAll(
        gen.text(
          _sanitize(data.customerName!.trim()),
          styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2,
            bold: true,
          ),
        ),
      );
    }

    // ─── Badge de tipo (para llevar / domicilio) ───
    final hasOwnLabel =
        data.tableLabel != null && data.tableLabel!.trim().isNotEmpty;
    if (hasOwnLabel &&
        (data.orderType == 'takeaway' || data.orderType == 'delivery')) {
      final typeLabel =
          data.orderType == 'takeaway' ? 'PARA LLEVAR' : 'DOMICILIO';
      bytes.addAll(
        gen.text(
          '>> $typeLabel <<',
          styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2,
            bold: true,
          ),
        ),
      );
    }

    // ─── Nº orden + hora ───
    bytes.addAll(
      gen.text(
        '${data.orderNumber}  ·  ${_hhmm(data.createdAt)}',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );

    // ─── Badge QR ───
    if (data.orderSource == 'qr_self_order') {
      bytes.addAll(
        gen.text(
          '** PEDIDO POR QR **',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      );
    }

    // ─── Teléfono (solo si hay, y solo en QR) ───
    if (data.orderSource == 'qr_self_order' &&
        data.customerPhone != null &&
        data.customerPhone!.isNotEmpty) {
      bytes.addAll(gen.text('Tel: ${data.customerPhone}'));
    }

    bytes.addAll(gen.hr());

    // ─── Items de esta categoría ───
    for (final item in items) {
      bytes.addAll(
        gen.text(
          '${item.quantity}x ${_sanitize(item.name.toUpperCase())}',
          styles: const PosStyles(
            bold: true,
            height: PosTextSize.size2,
          ),
        ),
      );
      if (item.variantName != null && item.variantName!.isNotEmpty) {
        bytes.addAll(
          gen.text(
            '  -> ${_sanitize(item.variantName!.toUpperCase())}',
            styles: const PosStyles(bold: true, height: PosTextSize.size2),
          ),
        );
      }
      if (item.selectedFlavors.isNotEmpty) {
        bytes.addAll(
          gen.text(
            '  * ${_sanitize(item.selectedFlavors.join(', '))}',
            styles: const PosStyles(bold: true),
          ),
        );
      }
      if (item.specialInstructions != null &&
          item.specialInstructions!.isNotEmpty) {
        bytes.addAll(
          gen.text(
            '  >> ${_sanitize(item.specialInstructions!)}',
            styles: const PosStyles(bold: true),
          ),
        );
      }
      // Sin línea en blanco entre ítems: el nombre en doble alto (size2)
      // ya separa visualmente cada producto y ahorra MUCHO papel en
      // comandas largas.
    }

    // ─── Notas generales (se repiten en cada comanda) ───
    if (data.notes != null && data.notes!.isNotEmpty) {
      bytes.addAll(gen.hr());
      bytes.addAll(
        gen.text('NOTAS:', styles: const PosStyles(bold: true)),
      );
      // _sanitize: las notas del cliente pueden tener emojis (ej. 🧅)
      // que el encoder ESC/POS lanza excepción al no caber en Latin-1.
      bytes.addAll(gen.text(_sanitize(data.notes!)));
    }

    bytes.addAll(gen.hr());
    bytes.addAll(
      gen.text(
        'Impreso ${_hhmm(DateTime.now())}',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );

    // Avance mínimo + corte → ticket independiente por categoría.
    // (feed(1) en vez de 2: el corte ya deja margen y ahorra papel.)
    bytes.addAll(gen.feed(1));
    bytes.addAll(gen.cut());
  }

  /// Genera recibo del cliente (con precios + totales + método de pago).
  static Future<Uint8List> buildReceipt({
    required TicketData data,
    required int paperWidthMm,
  }) async {
    final profile = await CapabilityProfile.load();
    final paper = paperWidthMm == 58 ? PaperSize.mm58 : PaperSize.mm80;
    final gen = Generator(paper, profile);

    final bytes = <int>[];
    bytes.addAll(gen.reset());
    // NO cambiamos la página de código: impresora en CP437 nativo.
    // _sanitize() ya convirtió los caracteres al byte CP437 correcto.

    // ─── Logo (opcional, solo recibo) ───
    // Si el negocio configuró un logo lo imprimimos centrado arriba del
    // nombre. Envuelto en try/catch: un logo corrupto/raro NUNCA debe
    // tumbar la impresión del recibo (el cobro ya pasó).
    _writeLogo(gen, bytes, data, paperWidthMm);

    // ─── Header del negocio ───
    bytes.addAll(
      gen.text(
        _sanitize(data.businessName.toUpperCase()),
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
        ),
      ),
    );
    if (data.address != null && data.address!.isNotEmpty) {
      bytes.addAll(
        gen.text(
          data.address!,
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }
    if (data.phone != null && data.phone!.isNotEmpty) {
      bytes.addAll(
        gen.text(
          'Tel: ${data.phone}',
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }
    if (data.taxId != null && data.taxId!.isNotEmpty) {
      bytes.addAll(
        gen.text(
          'NIT: ${data.taxId}',
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }

    bytes.addAll(
      gen.text(
        'RECIBO DE VENTA',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    bytes.addAll(gen.hr());

    // ─── Metadata ───
    bytes.addAll(
      gen.text('Orden: ${data.orderNumber}',
          styles: const PosStyles(bold: true)),
    );
    bytes.addAll(gen.text('Fecha: ${_fullDate(data.createdAt)}'));
    final recDest = _destinationLabel(data);
    if (data.customerName != null &&
        data.customerName!.trim().isNotEmpty &&
        data.customerName!.trim() != recDest) {
      bytes.addAll(gen.text('Cliente: ${_sanitize(data.customerName!.trim())}'));
      if (data.customerPhone != null && data.customerPhone!.isNotEmpty) {
        bytes.addAll(gen.text('Tel: ${data.customerPhone}'));
      }
    }
    bytes.addAll(gen.text('Atención: $recDest'));

    bytes.addAll(gen.hr());

    // ─── Items con precios ───
    for (final item in data.items) {
      bytes.addAll(
        gen.row([
          PosColumn(
            text: '${item.quantity} x ${_sanitize(item.name)}',
            width: 8,
          ),
          PosColumn(
            text: _money(item.subtotal),
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
      if (item.variantName != null && item.variantName!.isNotEmpty) {
        bytes.addAll(gen.text('  ${_sanitize(item.variantName!)}'));
      }
      if (item.specialInstructions != null &&
          item.specialInstructions!.isNotEmpty) {
        bytes.addAll(gen.text('  (${_sanitize(item.specialInstructions!)})'));
      }
      if (item.quantity > 1) {
        bytes.addAll(gen.text('  ${_money(item.unitPrice)} c/u'));
      }
    }

    bytes.addAll(gen.hr());

    // ─── Totales ───
    if (data.subtotal != data.totalAmount ||
        data.taxAmount > 0 ||
        data.discountAmount > 0) {
      bytes.addAll(
        gen.row([
          PosColumn(text: 'Subtotal:', width: 8),
          PosColumn(
            text: _money(data.subtotal),
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
    }
    if (data.discountAmount > 0) {
      bytes.addAll(
        gen.row([
          PosColumn(text: 'Descuento:', width: 8),
          PosColumn(
            text: '- ${_money(data.discountAmount)}',
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
    }
    if (data.taxAmount > 0) {
      bytes.addAll(
        gen.row([
          PosColumn(text: 'Impuestos:', width: 8),
          PosColumn(
            text: _money(data.taxAmount),
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
    }
    if (data.tipAmount > 0) {
      bytes.addAll(
        gen.row([
          PosColumn(text: 'Propina:', width: 8),
          PosColumn(
            text: _money(data.tipAmount),
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
    }

    // TOTAL en grande.
    bytes.addAll(
      gen.row([
        PosColumn(
          text: 'TOTAL',
          width: 6,
          styles: const PosStyles(bold: true, height: PosTextSize.size2),
        ),
        PosColumn(
          text: _money(data.totalAmount),
          width: 6,
          styles: const PosStyles(
            align: PosAlign.right,
            bold: true,
            height: PosTextSize.size2,
          ),
        ),
      ]),
    );

    if (data.paymentMethod != null && data.paymentMethod!.isNotEmpty) {
      bytes.addAll(gen.feed(1));
      bytes.addAll(
        gen.text('Pago: ${_formatPaymentMethod(data.paymentMethod!)}'),
      );
    }

    bytes.addAll(gen.hr());
    bytes.addAll(
      gen.text(
        '¡Gracias por tu visita!',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      gen.text(
        _fullDate(DateTime.now()),
        styles: const PosStyles(align: PosAlign.center),
      ),
    );

    bytes.addAll(gen.feed(1));
    bytes.addAll(gen.cut());

    return Uint8List.fromList(bytes);
  }

  // ── Helpers ──────────────────────────────────────────────────────

  /// Convierte texto Unicode a una cadena cuyos code-units son bytes CP437.
  ///
  /// La impresora térmica opera en su CP437 nativo (US English, el default
  /// tras ESC @). El codec `latin1` del Generator envía cada code-unit como
  /// un byte directo. Esta función mapea cada carácter Unicode al byte CP437
  /// que lo representa, de modo que lo que sale del codec = lo que la
  /// impresora muestra correctamente.
  ///
  /// Reglas:
  ///   1. ASCII 0x20–0x7E: idéntico en todos los code-pages → pasa directo.
  ///   2. Caracteres con mapping CP437 explícito → se convierten al byte.
  ///   3. Caracteres tipográficos Unicode comunes → ASCII equivalente.
  ///   4. Emojis y caracteres sin equivalente → se omiten silenciosamente.
  ///   5. Espacios dobles resultantes de omisiones → se colapsan.
  ///
  /// Ejemplos:
  ///   “Perro Montañero”.toUpperCase() → “PERRO MONTA\xA5ERO”
  ///     → impresora CP437 lee 0xA5 = Ñ → imprime “PERRO MONTAÑERO” ✓
  ///   “Sin cebolla todo🧅” → “Sin cebolla todo” (emoji omitido) ✓
  static String _sanitize(String text) {
    final buf = StringBuffer();
    for (final r in text.runes) {
      if (r >= 0x20 && r <= 0x7E) {
        buf.writeCharCode(r); // ASCII imprimible estándar
      } else if (r == 0x09 || r == 0x00A0) {
        buf.writeCharCode(0x20); // Tab / espacio duro → espacio
      } else if (r == 0x2018 || r == 0x2019) {
        buf.writeCharCode(0x27); // Comillas simples tipográficas → '
      } else if (r == 0x201C || r == 0x201D) {
        buf.writeCharCode(0x22); // Comillas dobles tipográficas → “
      } else if (r == 0x2013) {
        buf.writeCharCode(0x2D); // En-dash → -
      } else if (r == 0x2014) {
        buf.write('--'); // Em-dash → --
      } else if (r == 0x2026) {
        buf.write('...'); // Elipsis → ...
      } else {
        final byte = _cp437[r];
        if (byte != null) buf.writeCharCode(byte);
        // Emoji y caracteres sin mapping → omitir silenciosamente
      }
    }
    return buf.toString().replaceAll(RegExp(r' {2,}'), ' ').trim();
  }

  /// Tabla Unicode → byte CP437. Cubre todo el español y caracteres
  /// frecuentes en nombres de restaurante latinoamericano.
  /// Fuente: https://en.wikipedia.org/wiki/Code_page_437
  static const Map<int, int> _cp437 = {
    // ── Minúsculas con acento (español) ──
    0x00E0: 0x85, // à
    0x00E1: 0xA0, // á ← clave español
    0x00E2: 0x83, // â
    0x00E4: 0x84, // ä
    0x00E5: 0x86, // å
    0x00E6: 0x91, // æ
    0x00E7: 0x87, // ç
    0x00E8: 0x8A, // è
    0x00E9: 0x82, // é ← clave español
    0x00EA: 0x88, // ê
    0x00EB: 0x89, // ë
    0x00EC: 0x8D, // ì
    0x00EE: 0x8C, // î
    0x00EF: 0x8B, // ï
    0x00F1: 0xA4, // ñ ← clave español
    0x00F2: 0x95, // ò
    0x00F3: 0xA2, // ó ← clave español
    0x00F4: 0x93, // ô
    0x00F6: 0x94, // ö
    0x00F9: 0x97, // ù
    0x00FA: 0xA3, // ú ← clave español
    0x00FB: 0x96, // û
    0x00FC: 0x81, // ü ← clave español
    0x00FF: 0x98, // ÿ
    // ── Mayúsculas con acento ──
    // Nota: Á Í Ó Ú no existen en CP437 → usamos la versión sin tilde.
    // Ñ, É, Ü, Ä, Ö sí existen en CP437 y se mapean exactamente.
    0x00C0: 0x41, // À → A
    0x00C1: 0x41, // Á → A
    0x00C2: 0x41, // Â → A
    0x00C4: 0x8E, // Ä ✓
    0x00C5: 0x8F, // Å ✓
    0x00C6: 0x92, // Æ ✓
    0x00C7: 0x80, // Ç ✓
    0x00C8: 0x45, // È → E
    0x00C9: 0x90, // É ✓ ← clave español
    0x00CA: 0x45, // Ê → E
    0x00CB: 0x45, // Ë → E
    0x00CC: 0x49, // Ì → I
    0x00CD: 0x49, // Í → I
    0x00CE: 0x49, // Î → I
    0x00CF: 0x49, // Ï → I
    0x00D1: 0xA5, // Ñ ✓ ← clave español
    0x00D2: 0x4F, // Ò → O
    0x00D3: 0x4F, // Ó → O
    0x00D4: 0x4F, // Ô → O
    0x00D6: 0x99, // Ö ✓
    0x00D8: 0x4F, // Ø → O
    0x00D9: 0x55, // Ù → U
    0x00DA: 0x55, // Ú → U
    0x00DB: 0x55, // Û → U
    0x00DC: 0x9A, // Ü ✓
    0x00DD: 0x59, // Ý → Y
    // ── Puntuación española y símbolos comunes ──
    0x00A1: 0xAD, // ¡ ✓
    0x00A2: 0x9B, // ¢ ✓
    0x00A3: 0x9C, // £ ✓
    0x00A5: 0x9D, // ¥ ✓
    0x00A6: 0x7C, // ¦ → |
    0x00A9: 0x43, // © → C
    0x00AA: 0xA6, // ª ✓
    0x00AB: 0xAE, // « ✓
    0x00AC: 0xAA, // ¬ ✓
    0x00AE: 0x52, // ® → R
    0x00B0: 0xF8, // ° (grados) ✓
    0x00B1: 0xF1, // ± ✓
    0x00B2: 0x32, // ² → 2
    0x00B3: 0x33, // ³ → 3
    0x00B5: 0xE6, // µ ✓
    0x00BA: 0xA7, // º ✓
    0x00BB: 0xAF, // » ✓
    0x00BC: 0xAC, // ¼ ✓
    0x00BD: 0xAB, // ½ ✓
    0x00BF: 0xA8, // ¿ ✓
    0x20AC: 0x65, // € → e (no existe en CP437 estándar)
  };

  /// Imprime el logo del negocio centrado (solo recibo). Decodifica los
  /// bytes, lo escala al ancho del papel y lo manda como raster. Si algo
  /// falla (bytes corruptos, formato raro), no imprime nada — el recibo
  /// sigue saliendo igual de bien.
  static void _writeLogo(
    Generator gen,
    List<int> bytes,
    TicketData data,
    int paperWidthMm,
  ) {
    final raw = data.logoBytes;
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = img.decodeImage(raw);
      if (decoded == null) return;
      // Ancho útil del papel en puntos: 58mm≈384, 80mm≈576. Topamos para
      // que el logo no se desborde ni desperdicie papel.
      final maxWidth = paperWidthMm == 58 ? 360 : 500;
      final resized = decoded.width > maxWidth
          ? img.copyResize(decoded, width: maxWidth)
          : decoded;
      bytes.addAll(gen.image(resized));
      bytes.addAll(gen.feed(1));
    } catch (_) {
      // Logo inválido → lo ignoramos.
    }
  }

  /// Etiqueta de destino para la comanda: si la orden tiene etiqueta propia
  /// (mesa "Mesa 5" o cuenta libre "papa") se usa esa; si no, el tipo en
  /// coloquial. Evita "PICKUP"/"SIN MESA" y el falso "PARA LLEVAR".
  static String _destinationLabel(TicketData data) {
    final label = data.tableLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    switch (data.orderType) {
      case 'takeaway':
        return 'PARA LLEVAR';
      case 'delivery':
        return 'DOMICILIO';
      case 'dine_in':
        return 'EN EL SALÓN';
      default:
        return 'PEDIDO';
    }
  }

  static String _formatPaymentMethod(String method) {
    switch (method) {
      case 'cash':
        return 'Efectivo';
      case 'card':
        return 'Tarjeta';
      case 'transfer':
        return 'Transferencia';
      case 'digital_wallet':
        return 'Billetera Digital';
      default:
        return method;
    }
  }

  static String _money(double n) => CurrencyFormatter.format(n);

  // Las fechas del backend vienen en UTC (…Z). Convertimos a hora LOCAL
  // del dispositivo (ej. Colombia UTC-5) para que la hora de la comanda
  // sea la real, no 5 horas adelantada.
  static String _hhmm(DateTime d) {
    final l = d.toLocal();
    final h = l.hour;
    final period = h < 12 ? 'AM' : 'PM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:${l.minute.toString().padLeft(2, '0')} $period';
  }

  static String _fullDate(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/'
        '${l.month.toString().padLeft(2, '0')}/'
        '${l.year}  ${_hhmm(l)}';
  }
}
