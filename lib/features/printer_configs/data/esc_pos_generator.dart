import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;

import '../../../core/config/formatters/currency_formatter.dart';
import '../../../core/config/formatters/datetime_formatter.dart';

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

  /// Número de turno de mostrador (ej. "42"). `null` = no imprimir la
  /// línea de turno — ya sea porque la orden no tiene turno, o porque
  /// el negocio apagó `settings.operation_mode.print_ticket_number`
  /// (el gate vive en `PrintingOrchestrator._buildTicketData`, no acá).
  final int? ticketNumber;
  final DateTime createdAt;
  final String? tableLabel;
  final String orderType; // dine_in / takeaway / delivery
  final String orderSource; // pos / qr_self_order

  /// Dirección de entrega ya formateada en una sola línea legible
  /// ("Calle 123 #45, Bogotá — timbre roto"), solo para `orderType ==
  /// 'delivery'`. `null` si no aplica o el cliente no la cargó. Se
  /// imprime en el RECIBO del cliente (no en la comanda de cocina —
  /// la cocina solo necesita saber que es domicilio, no a dónde).
  final String? deliveryAddress;

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
    this.ticketNumber,
    required this.createdAt,
    required this.tableLabel,
    required this.orderType,
    required this.orderSource,
    this.deliveryAddress,
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
  /// imprime un ticket separado por cada una (salvo que el tenant haya
  /// agrupado varias en un mismo bloque de impresión — ver
  /// `EscPosGenerator.buildKitchen`'s `printGroups`).
  final String? categoryName;

  /// Id real de la categoría — se usa para resolver los bloques de
  /// impresión configurados por el tenant. `categoryName` es solo para
  /// mostrar/agrupar visualmente.
  final String? categoryId;

  /// Si la categoría imprime comanda. Items en `false` no salen a cocina
  /// aunque `requiresPreparation` sea true. Default `true`.
  final bool categoryPrintsKitchen;

  /// Cremas/sabores elegidos (uno por bola) — se imprimen en la comanda.
  final List<String> selectedFlavors;

  /// Extras/adicionales elegidos (ej. "Coca-Cola Cero"). Se imprimen
  /// aparte de `variantName`: sin precio en la comanda, con precio en
  /// el recibo (ver `EscPosGenerator`).
  final List<TicketModifierLine> modifiers;

  const TicketItem({
    required this.quantity,
    required this.name,
    required this.variantName,
    required this.unitPrice,
    required this.subtotal,
    required this.specialInstructions,
    this.requiresPreparation = true,
    this.categoryName,
    this.categoryId,
    this.categoryPrintsKitchen = true,
    this.selectedFlavors = const [],
    this.modifiers = const [],
  });
}

/// Un extra/adicional elegido para un item (ej. "Coca-Cola Cero", $500).
class TicketModifierLine {
  final String name;
  final int quantity;

  /// Precio total de este extra (unitPrice * quantity) — 0 = gratis.
  final double subtotal;

  const TicketModifierLine({
    required this.name,
    required this.quantity,
    required this.subtotal,
  });
}

/// Un método de pago agregado del turno (ej. "Tarjeta: 3 cobros, $45.000").
class CashSessionMethodLine {
  final String method;
  final int count;
  final double total;

  const CashSessionMethodLine({
    required this.method,
    required this.count,
    required this.total,
  });
}

/// Bre-B desglosado por llave (ej. "@llaveUno: 2 cobros, $17.000").
class CashSessionLlaveLine {
  final String label;
  final int count;
  final double total;

  const CashSessionLlaveLine({
    required this.label,
    required this.count,
    required this.total,
  });
}

/// Datos para el ticket de cierre de caja — espejo de lo que arma
/// `ThermalPrintService.generateCashSessionReportPdf` en el backend
/// (mismo contenido, dos formatos: PDF allá para impresoras `system`,
/// ESC/POS acá para impresoras `network`).
class CashSessionReportData {
  final String businessName;
  final String? address;
  final String? phone;

  final String? cashierName;
  final DateTime openedAt;
  final DateTime? closedAt;
  final bool isOpen;

  final double openingAmount;
  final double cashCollected;
  final double cashExpenses;
  final double expectedAmount;
  final double? countedAmount;
  final double? difference;

  /// Métodos ≠ efectivo, EXCLUYENDO Bre-B cuando hay desglose por
  /// llave (ese caso se imprime línea-por-llave en `llaves`, no acá) —
  /// misma regla que el backend para no duplicar el total.
  final List<CashSessionMethodLine> otherMethods;
  final List<CashSessionLlaveLine> llaves;

  const CashSessionReportData({
    required this.businessName,
    required this.address,
    required this.phone,
    required this.cashierName,
    required this.openedAt,
    required this.closedAt,
    required this.isOpen,
    required this.openingAmount,
    required this.cashCollected,
    required this.cashExpenses,
    required this.expectedAmount,
    required this.countedAmount,
    required this.difference,
    required this.otherMethods,
    required this.llaves,
  });
}

/// Una categoría de cocina con sus items, ya agrupados por
/// `EscPosGenerator.buildKitchen` — unidad interna para resolver los
/// bloques de impresión configurados por el tenant.
class _KitchenCategory {
  final String name;
  final String? id;
  final List<TicketItem> items = [];

  _KitchenCategory({required this.name, required this.id});
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
    /// Bloques de impresión configurados por el tenant — cada entrada
    /// es una lista de IDs de categoría que deben salir juntas en UN
    /// SOLO documento (un único corte al final, sin repetir título/
    /// orden/pie por cada categoría — solo su nombre como separador).
    /// Una categoría que no aparece en ningún bloque sigue saliendo
    /// SOLA, en su propio documento — comportamiento de siempre.
    /// Default `[]` = nadie agrupado = comportamiento de siempre para
    /// TODAS las categorías. Ver `PrintingOrchestrator._getTenantInfo`.
    List<List<String>> printGroups = const [],
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

    // 1) Agrupar por categoría preservando el orden de aparición.
    final byCategory = <String, _KitchenCategory>{};
    for (final item in kitchenItems) {
      // Clave de agrupación VISUAL (nombre) — dos categorías con el
      // mismo nombre (raro, pero posible con sub-categorías) comparten
      // ticket igual que antes. El id (para resolver bloques) es el de
      // la PRIMERA vez que se ve esa clave.
      final key = (item.categoryName ?? 'GENERAL').toUpperCase();
      final bucket = byCategory.putIfAbsent(
        key,
        () => _KitchenCategory(name: key, id: item.categoryId),
      );
      bucket.items.add(item);
    }
    final categories = byCategory.values.toList();

    // 2) Resolver a qué "ticket físico" (bloque de impresión) pertenece
    // cada categoría, preservando el orden de aparición de los bloques.
    // categoryId -> índice de bloque configurado (si el tenant lo agrupó).
    final groupIndexByCategoryId = <String, int>{};
    for (var g = 0; g < printGroups.length; g++) {
      for (final categoryId in printGroups[g]) {
        groupIndexByCategoryId[categoryId] = g;
      }
    }
    final tickets = <String, List<_KitchenCategory>>{};
    for (final cat in categories) {
      // Sin id (no debería pasar, pero por si acaso) o no configurada
      // en ningún bloque → su propio ticket, como siempre.
      final groupIndex = cat.id != null ? groupIndexByCategoryId[cat.id] : null;
      final ticketKey = groupIndex != null
          ? 'group_$groupIndex'
          : 'solo_${cat.name}';
      tickets.putIfAbsent(ticketKey, () => []).add(cat);
    }

    // 3) Escribir cada ticket físico resuelto — cada uno con su propio
    // corte al final (el corte separa TICKETS, no categorías dentro de
    // un mismo ticket fusionado).
    for (final ticketCategories in tickets.values) {
      _writeKitchenTicket(gen, bytes, data, ticketCategories);
    }

    return Uint8List.fromList(bytes);
  }

  /// Escribe UN ticket físico completo — una o varias categorías juntas
  /// (según cómo haya resuelto `buildKitchen` los bloques de impresión).
  ///
  /// Si [categories] trae UNA sola categoría: comportamiento de
  /// siempre — su nombre sale GRANDE como parte del header (como el
  /// "destino"), exactamente igual a como se veía antes de que
  /// existieran los bloques de impresión.
  ///
  /// Si trae VARIAS (el tenant las agrupó en un mismo bloque): el
  /// título/destino/turno/Nº de orden/notas/"Impreso" se escriben UNA
  /// sola vez — pedido real: no tiene sentido repetirlos si va todo en
  /// el mismo papel. El ÚNICO separador entre categorías es su
  /// nombre, antes de sus items.
  static void _writeKitchenTicket(
    Generator gen,
    List<int> bytes,
    TicketData data,
    List<_KitchenCategory> categories,
  ) {
    final solo = categories.length == 1;
    _writeKitchenHeader(
      gen,
      bytes,
      data,
      soloCategoryName: solo ? categories.first.name : null,
    );
    for (final cat in categories) {
      if (!solo) {
        _writeCategoryDivider(gen, bytes, cat.name);
      }
      _writeKitchenItemsList(gen, bytes, cat.items);
    }
    _writeKitchenFooter(gen, bytes, data);

    // Avance mínimo + corte → separa este ticket físico del siguiente.
    // (feed(1) en vez de 2: el corte ya deja margen y ahorra papel.)
    bytes.addAll(gen.feed(1));
    bytes.addAll(gen.cut());
  }

  /// Header común: título + (categoría grande, solo si [soloCategoryName]
  /// viene) + destino + turno + cliente + badge para llevar/domicilio +
  /// Nº de orden/hora + badge QR + teléfono.
  static void _writeKitchenHeader(
    Generator gen,
    List<int> bytes,
    TicketData data, {
    String? soloCategoryName,
  }) {
    // ─── "COMANDA" + categoría (si aplica) ───
    // "COMANDA" en tamaño normal (es solo la etiqueta); la categoría
    // (estación) y el destino se mantienen grandes y legibles. Ahorra papel.
    bytes.addAll(
      gen.text(
        'COMANDA',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    if (soloCategoryName != null) {
      bytes.addAll(
        gen.text(
          _sanitize(soloCategoryName),
          styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2,
            bold: true,
          ),
        ),
      );
    }

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

    // ─── Turno de mostrador (GRANDE, lo más importante del ticket) ───
    // Solo llega no-null si el negocio activó imprimir turno — ver
    // el comentario de `TicketData.ticketNumber`.
    if (data.ticketNumber != null) {
      bytes.addAll(
        gen.text(
          'TURNO: ${data.ticketNumber}',
          styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size3,
            width: PosTextSize.size3,
            bold: true,
          ),
        ),
      );
    }

    // ─── Nombre del cliente (justo bajo el destino) ───
    // Para pedidos QR siempre lo imprimimos en tamaño grande para que
    // el mesero identifique al cliente de un vistazo. Para pedidos del
    // POS lo imprimimos solo si difiere del destino (evita repetir
    // "Mostrador / Mostrador").
    final hasCustomer =
        data.customerName != null &&
        data.customerName!.trim().isNotEmpty &&
        data.customerName!.trim() != destination;
    if (hasCustomer) {
      // Mayúscula ANTES de `_sanitize` — `toUpperCase()` de Dart ya
      // respeta tildes y ñ ('josé' → 'JOSÉ', 'ñ' → 'Ñ'); `_sanitize`
      // se encarga de mapear esos caracteres al byte CP437 correcto.
      bytes.addAll(
        gen.text(
          _sanitize(data.customerName!.trim().toUpperCase()),
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
      final typeLabel = data.orderType == 'takeaway'
          ? 'PARA LLEVAR'
          : 'DOMICILIO';
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
  }

  /// Separador entre categorías DENTRO de un mismo ticket fusionado —
  /// pedido explícito: "el único separador fuera el nombre de la
  /// categoría" (sin repetir título/destino/orden).
  static void _writeCategoryDivider(
    Generator gen,
    List<int> bytes,
    String categoryName,
  ) {
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
  }

  /// Lista de items de UNA categoría — cantidad, variante, sabores,
  /// extras y nota, en el mismo orden/formato de siempre.
  static void _writeKitchenItemsList(
    Generator gen,
    List<int> bytes,
    List<TicketItem> items,
  ) {
    for (final item in items) {
      bytes.addAll(
        gen.text(
          '${item.quantity}x ${_sanitize(item.name.toUpperCase())}',
          styles: const PosStyles(bold: true, height: PosTextSize.size2),
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
      // Extras/adicionales elegidos (ej. "Coca-Cola Cero") — sin precio,
      // cocina/barra solo necesita saber CON QUÉ se entrega el plato.
      if (item.modifiers.isNotEmpty) {
        final modifiersLine = item.modifiers
            .map((m) => m.quantity > 1 ? '${m.quantity}x ${m.name}' : m.name)
            .join(', ');
        bytes.addAll(
          gen.text(
            '  + ${_sanitize(modifiersLine)}',
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
  }

  /// Footer común: notas generales del pedido + "Impreso HH:MM".
  static void _writeKitchenFooter(
    Generator gen,
    List<int> bytes,
    TicketData data,
  ) {
    if (data.notes != null && data.notes!.isNotEmpty) {
      bytes.addAll(gen.hr());
      bytes.addAll(gen.text('NOTAS:', styles: const PosStyles(bold: true)));
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
  }

  /// Genera recibo del cliente (con precios + totales + método de pago).
  /// Ticket de cierre de caja: fondo esperado en caja + desglose 100%
  /// dinámico de "otros medios de pago" (Bre-B abierto por llave).
  /// Espejo ESC/POS de `ThermalPrintService.generateCashSessionReportPdf`
  /// del backend — mismo contenido, para impresoras `network`.
  static Future<Uint8List> buildCashSessionReport({
    required CashSessionReportData data,
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

    bytes.addAll(
      gen.text(
        'CIERRE DE CAJA',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    bytes.addAll(gen.hr());

    // ─── Metadata de sesión ───
    if (data.cashierName != null && data.cashierName!.isNotEmpty) {
      bytes.addAll(gen.text('Cajero: ${_sanitize(data.cashierName!)}'));
    }
    bytes.addAll(
      gen.text('Apertura: ${DateTimeFormatter.receiptDateTime(data.openedAt)}'),
    );
    bytes.addAll(
      gen.text(
        data.closedAt != null
            ? 'Cierre: ${DateTimeFormatter.receiptDateTime(data.closedAt!)}'
            : 'Cierre: En curso',
      ),
    );

    bytes.addAll(gen.hr());

    // ─── Efectivo / fondo esperado ───
    bytes.addAll(
      gen.row([
        PosColumn(text: 'Fondo inicial:', width: 8),
        PosColumn(
          text: _money(data.openingAmount),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]),
    );
    bytes.addAll(
      gen.row([
        PosColumn(text: 'Cobros en efectivo:', width: 8),
        PosColumn(
          text: _money(data.cashCollected),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]),
    );
    if (data.cashExpenses > 0) {
      bytes.addAll(
        gen.row([
          PosColumn(text: 'Gastos del turno:', width: 8),
          PosColumn(
            text: '- ${_money(data.cashExpenses)}',
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
    }

    bytes.addAll(
      gen.text('FONDO ESPERADO EN CAJA', styles: const PosStyles(bold: true)),
    );
    bytes.addAll(
      gen.text(
        _money(data.expectedAmount),
        styles: const PosStyles(
          align: PosAlign.right,
          bold: true,
          height: PosTextSize.size2,
        ),
      ),
    );

    if (!data.isOpen && data.countedAmount != null) {
      bytes.addAll(
        gen.row([
          PosColumn(text: 'Contado al cierre:', width: 8),
          PosColumn(
            text: _money(data.countedAmount!),
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
      final diff = data.difference ?? 0;
      bytes.addAll(
        gen.row([
          PosColumn(text: 'Diferencia:', width: 8),
          PosColumn(
            text: '${diff >= 0 ? '+' : ''}${_money(diff)}',
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
    }

    bytes.addAll(gen.hr());

    // ─── Otros medios de pago (dinámico, sin hardcodear métodos) ───
    bytes.addAll(
      gen.text('OTROS MEDIOS DE PAGO', styles: const PosStyles(bold: true)),
    );

    if (data.otherMethods.isEmpty && data.llaves.isEmpty) {
      bytes.addAll(gen.text('(sin cobros en otros metodos)'));
    }

    for (final m in data.otherMethods) {
      bytes.addAll(
        gen.row([
          PosColumn(
            text: '${_formatPaymentMethod(m.method)} (${m.count})',
            width: 8,
          ),
          PosColumn(
            text: _money(m.total),
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
    }
    for (final l in data.llaves) {
      bytes.addAll(
        gen.row([
          PosColumn(text: 'Bre-B ${_sanitize(l.label)} (${l.count})', width: 8),
          PosColumn(
            text: _money(l.total),
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
    }

    bytes.addAll(gen.hr());
    bytes.addAll(
      gen.text(
        'Cierre generado el',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      gen.text(
        DateTimeFormatter.receiptDateTime(DateTime.now()),
        styles: const PosStyles(align: PosAlign.center),
      ),
    );

    bytes.addAll(gen.feed(1));
    bytes.addAll(gen.cut());

    return Uint8List.fromList(bytes);
  }

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

    // ─── Turno de mostrador (GRANDE) — el cliente lo guarda como
    // comprobante de "su número". Ver comentario de TicketData.ticketNumber.
    if (data.ticketNumber != null) {
      bytes.addAll(
        gen.text(
          'TURNO: ${data.ticketNumber}',
          styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size3,
            width: PosTextSize.size3,
            bold: true,
          ),
        ),
      );
      bytes.addAll(gen.hr());
    }

    // ─── Metadata ───
    bytes.addAll(
      gen.text(
        'Orden: ${data.orderNumber}',
        styles: const PosStyles(bold: true),
      ),
    );
    bytes.addAll(gen.text('Fecha: ${_fullDate(data.createdAt)}'));
    final recDest = _destinationLabel(data);
    if (data.customerName != null &&
        data.customerName!.trim().isNotEmpty &&
        data.customerName!.trim() != recDest) {
      bytes.addAll(
        gen.text(
          'Cliente: ${_sanitize(data.customerName!.trim().toUpperCase())}',
          styles: const PosStyles(bold: true),
        ),
      );
      if (data.customerPhone != null && data.customerPhone!.isNotEmpty) {
        bytes.addAll(gen.text('Tel: ${data.customerPhone}'));
      }
    }
    bytes.addAll(gen.text('Atencion: $recDest'));

    // ─── Dirección de entrega (solo domicilio) — el cliente necesita
    // ver que quedó bien la dirección que dio, y quien reparte usa el
    // recibo como guía si no tiene otra referencia. ───
    if (data.orderType == 'delivery' &&
        data.deliveryAddress != null &&
        data.deliveryAddress!.trim().isNotEmpty) {
      bytes.addAll(
        gen.text(
          'Direccion: ${_sanitize(data.deliveryAddress!.trim())}',
          styles: const PosStyles(bold: true),
        ),
      );
    }

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
      // Extras/adicionales, CADA UNO con su precio — el cliente paga por
      // esto, tiene que verlo explícito y no solo el nombre.
      for (final mod in item.modifiers) {
        final qtyPrefix = mod.quantity > 1 ? '${mod.quantity}x ' : '';
        final priceText = mod.subtotal > 0 ? _money(mod.subtotal) : 'Gratis';
        bytes.addAll(
          gen.row([
            PosColumn(text: '  + $qtyPrefix${_sanitize(mod.name)}', width: 8),
            PosColumn(
              text: priceText,
              width: 4,
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]),
        );
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
  ///   2. Vocales con tilde/diéresis (á é í ó ú ä ë ï ö ü, mayúsculas
  ///      también) → se les quita el acento (á→a). La Ñ/ñ NO se toca,
  ///      sale bien en la impresora del cliente — ver la tabla `_cp437`.
  ///   3. Resto de caracteres con mapping CP437 explícito → al byte CP437.
  ///   4. Caracteres tipográficos Unicode comunes → ASCII equivalente.
  ///   5. Emojis y caracteres sin equivalente → se omiten silenciosamente.
  ///   6. Espacios dobles resultantes de omisiones → se colapsan.
  ///
  /// Ejemplos:
  ///   “Dirección”.toUpperCase() → “DIRECCION” (tilde quitada, sin símbolo raro) ✓
  ///   “Perro Montañero”.toUpperCase() → “PERRO MONTA\xA5ERO”
  ///     → impresora lee 0xA5 = Ñ → imprime “PERRO MONTAÑERO” ✓
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
    // ── Vocales con tilde/diéresis/acento → SIN acento ──
    //
    // Bug real reportado: los bytes altos de CP437 de abajo (0xA0, 0x82,
    // 0xA2, 0xA3, 0x81, 0x90, 0x9A, 0x99, 0x8E...) asumían que la
    // impresora del cliente tenía la tabla CP437 "de libro" — en la
    // práctica, en su impresora esos bytes salen como símbolos raros
    // (probablemente firmware clon con code page distinto). El cliente
    // pidió explícitamente: nunca más tildes rotas, prefiere la vocal
    // SIN tilde a un símbolo extraño — pero la Ñ/ñ sí le sale bien, así
    // que esa se deja intacta más abajo (0xA4/0xA5).
    0x00E0: 0x61, // à → a
    0x00E1: 0x61, // á → a ← clave español
    0x00E2: 0x61, // â → a
    0x00E4: 0x61, // ä → a
    0x00E5: 0x61, // å → a
    0x00E6: 0x91, // æ
    0x00E7: 0x87, // ç
    0x00E8: 0x65, // è → e
    0x00E9: 0x65, // é → e ← clave español
    0x00EA: 0x65, // ê → e
    0x00EB: 0x65, // ë → e
    0x00EC: 0x69, // ì → i
    0x00EE: 0x69, // î → i
    0x00EF: 0x69, // ï → i
    0x00F1: 0xA4, // ñ ← clave español (sale bien, se deja intacta)
    0x00F2: 0x6F, // ò → o
    0x00F3: 0x6F, // ó → o ← clave español
    0x00F4: 0x6F, // ô → o
    0x00F6: 0x6F, // ö → o
    0x00F9: 0x75, // ù → u
    0x00FA: 0x75, // ú → u ← clave español
    0x00FB: 0x75, // û → u
    0x00FC: 0x75, // ü → u ← clave español
    0x00FF: 0x79, // ÿ → y
    // ── Mayúsculas con tilde/diéresis/acento → SIN acento ──
    0x00C0: 0x41, // À → A
    0x00C1: 0x41, // Á → A
    0x00C2: 0x41, // Â → A
    0x00C4: 0x41, // Ä → A
    0x00C5: 0x41, // Å → A
    0x00C6: 0x92, // Æ
    0x00C7: 0x80, // Ç
    0x00C8: 0x45, // È → E
    0x00C9: 0x45, // É → E ← clave español
    0x00CA: 0x45, // Ê → E
    0x00CB: 0x45, // Ë → E
    0x00CC: 0x49, // Ì → I
    0x00CD: 0x49, // Í → I
    0x00CE: 0x49, // Î → I
    0x00CF: 0x49, // Ï → I
    0x00D1: 0xA5, // Ñ ← clave español (sale bien, se deja intacta)
    0x00D2: 0x4F, // Ò → O
    0x00D3: 0x4F, // Ó → O
    0x00D4: 0x4F, // Ô → O
    0x00D6: 0x4F, // Ö → O
    0x00D8: 0x4F, // Ø → O
    0x00D9: 0x55, // Ù → U
    0x00DA: 0x55, // Ú → U
    0x00DB: 0x55, // Û → U
    0x00DC: 0x55, // Ü → U
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
        return 'EN EL SALON';
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
      case 'nequi':
        return 'Nequi';
      case 'breb':
        return 'Bre-B';
      default:
        return method;
    }
  }

  static String _money(double n) => CurrencyFormatter.format(n);

  // Las fechas del backend vienen en UTC (…Z). Antes esto convertía con
  // `.toLocal()` (zona del DISPOSITIVO que imprime) — si esa zona no
  // está bien puesta, el ticket FÍSICO queda con la hora equivocada sin
  // forma de corregirlo después. `DateTimeFormatter` usa el offset fijo
  // de Bogotá (UTC-5) en vez de confiar en el dispositivo.
  static String _hhmm(DateTime d) => DateTimeFormatter.time12(d);

  static String _fullDate(DateTime d) {
    final bog = DateTimeFormatter.bogotaDateOnly(d);
    return '${bog.day.toString().padLeft(2, '0')}/'
        '${bog.month.toString().padLeft(2, '0')}/'
        '${bog.year}  ${_hhmm(d)}';
  }
}
