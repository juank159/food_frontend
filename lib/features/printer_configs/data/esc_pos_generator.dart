import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

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

  const TicketItem({
    required this.quantity,
    required this.name,
    required this.variantName,
    required this.unitPrice,
    required this.subtotal,
    required this.specialInstructions,
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

    // ─── Header: "COMANDA" + tipo de orden ───
    bytes.addAll(
      gen.text(
        'COMANDA',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        ),
      ),
    );
    bytes.addAll(
      gen.text(
        _formatOrderType(data.orderType),
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );

    // ─── Mesa / destino (GRANDE) ───
    bytes.addAll(gen.feed(1));
    final destination = data.tableLabel ??
        (data.orderType == 'takeaway' ? 'PICKUP' : 'SIN MESA');
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

    // ─── Nº orden + hora ───
    bytes.addAll(gen.feed(1));
    bytes.addAll(
      gen.text(
        '${data.orderNumber}  ·  ${_hhmm(data.createdAt)}',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );

    // ─── Si vino por QR, badge destacado ───
    if (data.orderSource == 'qr_self_order') {
      bytes.addAll(gen.feed(1));
      bytes.addAll(
        gen.text(
          '** PEDIDO POR QR **',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      );
    }

    // ─── Cliente (si hay) ───
    if (data.customerName != null && data.customerName!.isNotEmpty) {
      bytes.addAll(gen.feed(1));
      bytes.addAll(gen.text('Cliente: ${data.customerName}'));
      if (data.customerPhone != null && data.customerPhone!.isNotEmpty) {
        bytes.addAll(gen.text('Tel: ${data.customerPhone}'));
      }
    }

    bytes.addAll(gen.hr());

    // ─── Items (cantidad GRANDE + nombre + notas) ───
    for (final item in data.items) {
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
      if (item.specialInstructions != null &&
          item.specialInstructions!.isNotEmpty) {
        bytes.addAll(
          gen.text(
            '  >> ${item.specialInstructions}',
            styles: const PosStyles(bold: true),
          ),
        );
      }
      bytes.addAll(gen.feed(1));
    }

    // ─── Notas generales ───
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

    // Avance + corte.
    bytes.addAll(gen.feed(2));
    bytes.addAll(gen.cut());

    return Uint8List.fromList(bytes);
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

    bytes.addAll(gen.hr());
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
    if (data.customerName != null && data.customerName!.isNotEmpty) {
      bytes.addAll(gen.text('Cliente: ${data.customerName}'));
    }
    if (data.tableLabel != null && data.tableLabel!.isNotEmpty) {
      bytes.addAll(gen.text('Mesa: ${data.tableLabel}'));
    }
    bytes.addAll(gen.text('Tipo: ${_formatOrderType(data.orderType)}'));

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

    bytes.addAll(gen.feed(2));
    bytes.addAll(gen.cut());

    return Uint8List.fromList(bytes);
  }

  // ── Helpers ──────────────────────────────────────────────────────

  static String _formatOrderType(String type) {
    switch (type) {
      case 'dine_in':
        return 'EN MESA';
      case 'takeaway':
        return 'PARA LLEVAR';
      case 'delivery':
        return 'DOMICILIO';
      default:
        return type.toUpperCase();
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

  static String _hhmm(DateTime d) {
    return '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  static String _fullDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}  ${_hhmm(d)}';
  }
}
