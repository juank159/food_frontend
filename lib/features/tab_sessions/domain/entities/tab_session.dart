import 'package:equatable/equatable.dart';

/// Estado de una cuenta abierta. Coincide con el enum del backend
/// `TabSessionStatus`.
enum TabSessionStatus {
  open('open', 'Abierta'),
  settling('settling', 'Cobrando'),
  closed('closed', 'Cerrada'),
  voided('void', 'Anulada');

  final String value;
  final String displayName;

  const TabSessionStatus(this.value, this.displayName);

  static TabSessionStatus fromString(String value) {
    return TabSessionStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => TabSessionStatus.open,
    );
  }
}

/// Cuenta abierta de una mesa o sesión de delivery.
///
/// Agrupa N órdenes (tickets) relacionadas. El balance se calcula
/// como `total_amount - paid_amount` y es lo que el cliente todavía
/// debe pagar.
class TabSession extends Equatable {
  final String id;
  final String? tableId;
  final String? tableElementId;
  final String? tableName;
  final String? customerId;
  final String? customerName;
  final String openedBy;
  final String? openedByName;
  final DateTime openedAt;
  final String? closedBy;
  final String? closedByName;
  final DateTime? closedAt;
  final TabSessionStatus status;
  final int? partySize;
  final String? notes;

  // Rollups financieros — fuente: backend recompute idempotente.
  final int totalOrders;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double tipAmount;
  final double deliveryFee;
  final double totalAmount;
  final double paidAmount;
  final double balance;

  /// Tickets que componen la cuenta. Puede venir vacío cuando se
  /// listan sesiones (para no traer todo el grafo), o lleno cuando
  /// se carga el detalle.
  final List<dynamic> orders; // El tipo concreto viene del feature orders.

  const TabSession({
    required this.id,
    this.tableId,
    this.tableElementId,
    this.tableName,
    this.customerId,
    this.customerName,
    required this.openedBy,
    this.openedByName,
    required this.openedAt,
    this.closedBy,
    this.closedByName,
    this.closedAt,
    required this.status,
    this.partySize,
    this.notes,
    required this.totalOrders,
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.tipAmount,
    required this.deliveryFee,
    required this.totalAmount,
    required this.paidAmount,
    required this.balance,
    this.orders = const [],
  });

  /// Copia solo los campos editables vía `TabSessionRepository.update`
  /// (customerName/notes/partySize — la "etiqueta" de la cuenta). Null
  /// en un parámetro significa "no tocar ese campo", igual que en
  /// `update()` — no hace falta soportar "borrar explícitamente" acá
  /// porque el repositorio tampoco lo soporta.
  TabSession copyWithEditable({
    String? customerName,
    String? notes,
    int? partySize,
  }) {
    return TabSession(
      id: id,
      tableId: tableId,
      tableElementId: tableElementId,
      tableName: tableName,
      customerId: customerId,
      customerName: customerName ?? this.customerName,
      openedBy: openedBy,
      openedByName: openedByName,
      openedAt: openedAt,
      closedBy: closedBy,
      closedByName: closedByName,
      closedAt: closedAt,
      status: status,
      partySize: partySize ?? this.partySize,
      notes: notes ?? this.notes,
      totalOrders: totalOrders,
      subtotal: subtotal,
      taxAmount: taxAmount,
      discountAmount: discountAmount,
      tipAmount: tipAmount,
      deliveryFee: deliveryFee,
      totalAmount: totalAmount,
      paidAmount: paidAmount,
      balance: balance,
      orders: orders,
    );
  }

  /// Conveniencias de UI:

  bool get isOpen => status == TabSessionStatus.open;
  bool get isSettling => status == TabSessionStatus.settling;
  bool get isClosed => status == TabSessionStatus.closed;
  bool get isVoided => status == TabSessionStatus.voided;

  /// Saldo pendiente real (con tolerancia de centavos para evitar
  /// problemas de redondeo float).
  bool get hasPendingBalance => balance > 0.01;

  /// Cuenta lista para cerrarse: open, balance pagado.
  bool get canClose => isOpen && !hasPendingBalance;

  /// Número de turno de mostrador asignado a algún ticket de esta
  /// cuenta, si lo hay. `orders` llega como JSON crudo del backend
  /// (`ticket_number`, snake_case) — no se parsea a entidades acá
  /// para no acoplar este feature al de orders (mismo criterio que
  /// ya documentaba el campo `orders` más abajo).
  int? get _ticketNumber {
    for (final o in orders) {
      if (o is Map) {
        final v = o['ticket_number'];
        if (v is int) return v;
        if (v is num) return v.toInt();
      }
    }
    return null;
  }

  /// Label visible para el listado: "Mesa 7", "Turno 3", "Domicilio",
  /// "Pickup", o la etiqueta libre que el cajero puso al abrir la
  /// cuenta sin mesa (ej. "Césped #3", "Silla zona verde").
  ///
  /// Bug real reportado: "Mostrador" y "Turno de mostrador" son
  /// destinos MUY distintos para el usuario — antes una venta por
  /// turno podía heredar `customer_name: 'Mostrador'` (default
  /// genérico cuando no se tipeaba nombre) y esta pantalla terminaba
  /// mostrando "Mostrador" para una cuenta que en realidad era un
  /// turno. El identificador real y único de una venta por turno es
  /// el NÚMERO asignado (`ticket_number`) — se prioriza sobre
  /// cualquier nombre de cliente, igual que una mesa real.
  String displayLabel({String fallback = 'Sin mesa'}) {
    if (tableName != null && tableName!.isNotEmpty) return 'Mesa $tableName';
    final ticketNumber = _ticketNumber;
    if (ticketNumber != null) return 'Turno $ticketNumber';
    if (customerName != null && customerName!.isNotEmpty) return customerName!;
    // Cuenta libre: sin mesa ni cliente vinculado → usamos la primera
    // línea de `notes` como etiqueta (es donde se guarda al abrir desde
    // "Abrir cuenta libre"). Si el operario después agregó notas más
    // largas, mostramos solo la primera línea para no romper la card.
    if (!hasTable && notes != null && notes!.trim().isNotEmpty) {
      final firstLine = notes!.split('\n').first.trim();
      if (firstLine.isNotEmpty) return firstLine;
    }
    return fallback;
  }

  /// True cuando la cuenta está atada a una mesa del floor plan (o legacy).
  bool get hasTable =>
      (tableElementId != null && tableElementId!.isNotEmpty) ||
      (tableId != null && tableId!.isNotEmpty);

  @override
  List<Object?> get props => [
    id,
    tableId,
    tableElementId,
    tableName,
    customerId,
    customerName,
    openedBy,
    openedByName,
    openedAt,
    closedBy,
    closedByName,
    closedAt,
    status,
    partySize,
    notes,
    totalOrders,
    subtotal,
    taxAmount,
    discountAmount,
    tipAmount,
    deliveryFee,
    totalAmount,
    paidAmount,
    balance,
  ];
}
