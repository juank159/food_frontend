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
        categoryName,
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
          data.customerName!.trim(),
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
          '${item.quantity}x ${item.name.toUpperCase()}',
          styles: const PosStyles(
            bold: true,
            height: PosTextSize.size2,
          ),
        ),
      );
      if (item.variantName != null && item.variantName!.isNotEmpty) {
        bytes.addAll(gen.text('  -> ${item.variantName}'));
      }
      if (item.selectedFlavors.isNotEmpty) {
        bytes.addAll(
          gen.text(
            '  * ${item.selectedFlavors.join(', ')}',
            styles: const PosStyles(bold: true),
          ),
        );
      }
      if (item.specialInstructions != null &&
          item.specialInstructions!.isNotEmpty) {
        bytes.addAll(
          gen.text(
            '  >> ${item.specialInstructions}',
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
      bytes.addAll(gen.text(data.notes!));
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

    // ─── Logo (opcional, solo recibo) ───
    // Si el negocio configuró un logo lo imprimimos centrado arriba del
    // nombre. Envuelto en try/catch: un logo corrupto/raro NUNCA debe
    // tumbar la impresión del recibo (el cobro ya pasó).
    _writeLogo(gen, bytes, data, paperWidthMm);

    // ─── Header del negocio ───
    bytes.addAll(
      gen.text(
        data.businessName.toUpperCase(),
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
      bytes.addAll(gen.text('Cliente: ${data.customerName}'));
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
            text: '${item.quantity} x ${item.name}',
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
        bytes.addAll(gen.text('  ${item.variantName}'));
      }
      if (item.specialInstructions != null &&
          item.specialInstructions!.isNotEmpty) {
        bytes.addAll(gen.text('  (${item.specialInstructions})'));
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
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  static String _fullDate(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/'
        '${l.month.toString().padLeft(2, '0')}/'
        '${l.year}  ${_hhmm(l)}';
  }
}
