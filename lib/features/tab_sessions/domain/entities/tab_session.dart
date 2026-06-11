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

  /// Label visible para el listado: "Mesa 7", "Domicilio", "Pickup", o
  /// la etiqueta libre que el cajero puso al abrir la cuenta sin mesa
  /// (ej. "Césped #3", "Silla zona verde").
  String displayLabel({String fallback = 'Sin mesa'}) {
    if (tableName != null && tableName!.isNotEmpty) return 'Mesa $tableName';
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
