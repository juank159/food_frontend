import 'package:equatable/equatable.dart';
import '../../../../core/config/constants/order_enums.dart';
import 'order_item.dart';

/// Order Entity
/// Entidad de dominio para órdenes/pedidos
class Order extends Equatable {
  final String id;
  final String orderNumber;
  final OrderType orderType;
  final OrderSource orderSource;
  final OrderStatus status;
  final String? tableId;
  final String? tableElementId; // Floor Plan Table Element ID
  final String? tableName;
  /// Snapshot legible del nombre de la mesa al crear la orden.
  /// Siempre preferir este sobre tableElementId / tableName para
  /// mostrar al usuario.
  final String? tableLabel;
  /// ID de la cuenta abierta (TabSession) si esta orden pertenece a una.
  /// Si está seteado, el cobro NO se hace por orden sino consolidado
  /// desde la cuenta. La UI usa esto para mostrar el botón "Ver cuenta"
  /// en lugar de "Cobrar" directo.
  final String? tabSessionId;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final Map<String, dynamic>? deliveryAddress;
  final String? assignedTo;
  final String? assignedToName;
  final List<OrderItem> items;
  final double subtotal;
  final double discountAmount;
  final double? discountPercentage;
  final double deliveryFee;
  final double tipAmount;
  final double taxAmount;
  final double totalAmount;
  final PaymentMethod? paymentMethod;
  final PaymentStatus paymentStatus;
  /// Monto ya cobrado (suma de payments completed). Derivado del JSON
  /// del backend en `OrderModel.fromJson`. Permite a la UI mostrar
  /// progreso de pago parcial sin pedir extras requests.
  final double paidAmount;
  final String? specialInstructions;
  final int? estimatedTime;
  final DateTime? confirmedAt;
  final DateTime? preparedAt;
  final DateTime? deliveredAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.orderType,
    required this.orderSource,
    required this.status,
    this.tableId,
    this.tableElementId,
    this.tableName,
    this.tableLabel,
    this.tabSessionId,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.deliveryAddress,
    this.assignedTo,
    this.assignedToName,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    this.discountPercentage,
    required this.deliveryFee,
    required this.tipAmount,
    required this.taxAmount,
    required this.totalAmount,
    this.paymentMethod,
    required this.paymentStatus,
    this.paidAmount = 0,
    this.specialInstructions,
    this.estimatedTime,
    this.confirmedAt,
    this.preparedAt,
    this.deliveredAt,
    this.completedAt,
    this.cancelledAt,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Verifica si la orden está pendiente
  bool get isPending => status == OrderStatus.pending;

  /// Verifica si la orden está confirmada
  bool get isConfirmed => status == OrderStatus.confirmed;

  /// Verifica si la orden está en preparación
  bool get isPreparing => status == OrderStatus.preparing;

  /// Verifica si la orden está lista
  bool get isReady => status == OrderStatus.ready;

  /// Verifica si la orden fue entregada
  bool get isDelivered => status == OrderStatus.delivered;

  /// Verifica si la orden está completada
  bool get isCompleted => status == OrderStatus.completed;

  /// Verifica si la orden está cancelada
  bool get isCancelled => status == OrderStatus.cancelled;

  /// Verifica si la orden está activa (no finalizada)
  bool get isActive => status.isActive;

  /// Verifica si la orden está finalizada
  bool get isFinal => status.isFinal;

  /// Verifica si es una orden para delivery
  bool get isDelivery => orderType == OrderType.delivery;

  /// Verifica si es una orden para llevar
  bool get isTakeaway => orderType == OrderType.takeaway;

  /// Verifica si es una orden para comer en el local
  bool get isDineIn => orderType == OrderType.dineIn;

  /// Verifica si el pago está completado
  bool get isPaymentCompleted => paymentStatus == PaymentStatus.completed;

  /// Verifica si el pago está pendiente
  bool get isPaymentPending => paymentStatus == PaymentStatus.pending;

  /// Saldo restante por cobrar de esta orden. Nunca negativo.
  double get balance {
    final b = totalAmount - paidAmount;
    return b < 0 ? 0 : b;
  }

  /// Verdadero si hay algún pago registrado pero la orden NO está
  /// completamente pagada — caso "pagué $2k de $7k". La card lo usa
  /// para mostrar progreso visible aunque `payment_status` siga
  /// `pending`.
  bool get hasPartialPayment =>
      paidAmount > 0.01 && !isPaymentCompleted;

  /// Verdadero si esta orden pertenece a una cuenta abierta (TabSession).
  /// El cobro se hace consolidado desde la cuenta, no por orden.
  bool get belongsToTabSession =>
      tabSessionId != null && tabSessionId!.isNotEmpty;

  /// Verdadero si la orden está lista para cobrar (pago pendiente y la
  /// operación llegó a un estado donde cobrar tiene sentido).
  /// Excluye `cancelled` (nunca se cobra) y `pending`/`confirmed`/
  /// `preparing` (todavía en cocina, no se ha entregado nada).
  bool get isReadyToCharge {
    if (!isPaymentPending) return false;
    return status == OrderStatus.ready ||
        status == OrderStatus.delivered ||
        status == OrderStatus.completed;
  }

  /// Verifica si tiene instrucciones especiales
  bool get hasSpecialInstructions =>
      specialInstructions != null && specialInstructions!.isNotEmpty;

  /// Verifica si tiene cliente asignado
  bool get hasCustomer => customerId != null || customerName != null;

  /// Verifica si tiene mesa asignada. Cubre los dos sistemas:
  /// Label legible para mostrar al usuario, con fallback en cascada:
  /// 1. `tableLabel` — snapshot al crear, formato "Mesa 1 · Areas verdes"
  /// 2. `tableName` — nombre desde join legacy (sistema viejo)
  /// 3. `tableElementId` — UUID interno (último recurso, NO ideal pero
  ///    mejor que vacío)
  /// 4. "Sin mesa" si todo es null
  String get displayTableLabel {
    if (tableLabel != null && tableLabel!.trim().isNotEmpty) {
      return tableLabel!;
    }
    if (tableName != null && tableName!.trim().isNotEmpty) {
      return tableName!;
    }
    if (tableElementId != null && tableElementId!.trim().isNotEmpty) {
      // No deberíamos llegar acá si table_label se popula bien, pero
      // si pasa al menos mostramos algo no totalmente cripto.
      return 'Mesa (sin nombre)';
    }
    return 'Sin mesa';
  }

  /// `tableId` (legacy, casi nunca seteado) y `tableElementId` (floor
  /// plan actual). `tableName` viene resuelto desde el backend a
  /// partir del label de la mesa en el floor plan.
  bool get hasTable =>
      tableId != null || tableElementId != null || tableName != null;

  /// **ÚNICA fuente** del "destino" a mostrar en cards/headers: si la
  /// orden tiene etiqueta propia (mesa "Mesa 5" o cuenta libre "mama")
  /// se usa esa; si no, el tipo en coloquial. Evita el bug recurrente de
  /// mostrar "Para llevar" en cuentas/órdenes que NUNCA fueron para
  /// llevar. Usar SIEMPRE esto en vez de `orderType.displayName` para el
  /// destino visible.
  String get displayDestination {
    final label = tableLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    final name = tableName?.trim();
    if (name != null && name.isNotEmpty) return name;
    switch (orderType) {
      case OrderType.takeaway:
        return 'Para llevar';
      case OrderType.delivery:
        return 'Domicilio';
      case OrderType.dineIn:
        return 'En mesa';
    }
  }

  /// Verifica si está asignado a un usuario
  bool get isAssigned => assignedTo != null;

  /// Obtiene el número total de items
  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  /// Obtiene la cantidad de productos diferentes
  int get uniqueItems => items.length;

  /// Calcula el descuento efectivo
  double get effectiveDiscount {
    if (discountAmount > 0) return discountAmount;
    if (discountPercentage != null && discountPercentage! > 0) {
      return subtotal * (discountPercentage! / 100);
    }
    return 0;
  }

  @override
  List<Object?> get props => [
        id,
        orderNumber,
        orderType,
        orderSource,
        status,
        tableId,
        tableElementId,
        tableName,
        tabSessionId,
        customerId,
        customerName,
        customerPhone,
        customerEmail,
        deliveryAddress,
        assignedTo,
        assignedToName,
        items,
        subtotal,
        discountAmount,
        discountPercentage,
        deliveryFee,
        tipAmount,
        taxAmount,
        totalAmount,
        paymentMethod,
        paymentStatus,
        paidAmount,
        specialInstructions,
        estimatedTime,
        confirmedAt,
        preparedAt,
        deliveredAt,
        completedAt,
        cancelledAt,
        metadata,
        createdAt,
        updatedAt,
      ];

  /// Copia la entidad con cambios
  Order copyWith({
    String? id,
    String? orderNumber,
    OrderType? orderType,
    OrderSource? orderSource,
    OrderStatus? status,
    String? tableId,
    String? tableElementId,
    String? tableName,
    String? tabSessionId,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    Map<String, dynamic>? deliveryAddress,
    String? assignedTo,
    String? assignedToName,
    List<OrderItem>? items,
    double? subtotal,
    double? discountAmount,
    double? discountPercentage,
    double? deliveryFee,
    double? tipAmount,
    double? taxAmount,
    double? totalAmount,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    double? paidAmount,
    String? specialInstructions,
    int? estimatedTime,
    DateTime? confirmedAt,
    DateTime? preparedAt,
    DateTime? deliveredAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      orderType: orderType ?? this.orderType,
      orderSource: orderSource ?? this.orderSource,
      status: status ?? this.status,
      tableId: tableId ?? this.tableId,
      tableElementId: tableElementId ?? this.tableElementId,
      tableName: tableName ?? this.tableName,
      tabSessionId: tabSessionId ?? this.tabSessionId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      tipAmount: tipAmount ?? this.tipAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paidAmount: paidAmount ?? this.paidAmount,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      preparedAt: preparedAt ?? this.preparedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
