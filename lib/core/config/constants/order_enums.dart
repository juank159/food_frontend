library;

/// Order Enums
/// Enumeraciones para el módulo de órdenes

/// Tipo de orden
enum OrderType {
  dineIn('dine_in', 'En el Local'),
  takeaway('takeaway', 'Para Llevar'),
  delivery('delivery', 'Delivery');

  final String value;
  final String displayName;

  const OrderType(this.value, this.displayName);

  static OrderType fromString(String value) {
    return OrderType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => OrderType.dineIn,
    );
  }
}

/// Fuente/origen de la orden
enum OrderSource {
  pos('pos', 'POS'),
  mobileApp('mobile_app', 'App Móvil'),
  web('web', 'Web'),
  phone('phone', 'Teléfono');

  final String value;
  final String displayName;

  const OrderSource(this.value, this.displayName);

  static OrderSource fromString(String value) {
    return OrderSource.values.firstWhere(
      (source) => source.value == value,
      orElse: () => OrderSource.pos,
    );
  }
}

/// Estado de la orden
enum OrderStatus {
  /// Self-order recién llegada via QR, esperando que el mesero la
  /// apruebe (o rechace) antes de que entre al flujo normal.
  pendingReview('pending_review', 'Pendiente de aprobación'),
  pending('pending', 'Pendiente'),
  confirmed('confirmed', 'Confirmada'),
  preparing('preparing', 'En Preparación'),
  ready('ready', 'Lista'),
  delivered('delivered', 'Entregada'),
  completed('completed', 'Completada'),
  cancelled('cancelled', 'Cancelada');

  final String value;
  final String displayName;

  const OrderStatus(this.value, this.displayName);

  static OrderStatus fromString(String value) {
    return OrderStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => OrderStatus.pending,
    );
  }

  /// Verifica si el estado es final (no se puede modificar)
  bool get isFinal =>
      this == OrderStatus.completed || this == OrderStatus.cancelled;

  /// Verifica si el estado es activo (orden en proceso)
  bool get isActive =>
      this == OrderStatus.pendingReview ||
      this == OrderStatus.pending ||
      this == OrderStatus.confirmed ||
      this == OrderStatus.preparing ||
      this == OrderStatus.ready ||
      this == OrderStatus.delivered;
}

/// Método de pago
enum PaymentMethod {
  cash('cash', 'Efectivo'),
  card('card', 'Tarjeta'),
  transfer('transfer', 'Transferencia'),
  digitalWallet('digital_wallet', 'Billetera Digital');

  final String value;
  final String displayName;

  const PaymentMethod(this.value, this.displayName);

  static PaymentMethod fromString(String value) {
    return PaymentMethod.values.firstWhere(
      (method) => method.value == value,
      orElse: () => PaymentMethod.cash,
    );
  }
}

/// Estado del pago
enum PaymentStatus {
  pending('pending', 'Pendiente'),
  completed('completed', 'Completado'),
  failed('failed', 'Fallido'),
  refunded('refunded', 'Reembolsado');

  final String value;
  final String displayName;

  const PaymentStatus(this.value, this.displayName);

  static PaymentStatus fromString(String value) {
    return PaymentStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => PaymentStatus.pending,
    );
  }
}
