import 'package:equatable/equatable.dart';

/// Un plato que un invitado puntual pidió dentro del pre-pedido
/// colaborativo de una reserva. Ver `ReservationPreOrderItem` en el
/// backend — 1:1 con esa fila.
class ReservationPreorderItem extends Equatable {
  final String? id;
  final String productName;
  final String? variantName;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final String? notes;

  const ReservationPreorderItem({
    this.id,
    required this.productName,
    this.variantName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.notes,
  });

  @override
  List<Object?> get props =>
      [id, productName, variantName, quantity, unitPrice, subtotal, notes];
}

/// Todo lo que UN invitado pidió (agrupado por el nombre que escribió al
/// entrar al link público — sin cuenta ni auth, así que es texto libre).
class ReservationPreorderGuest extends Equatable {
  final String guestName;
  final List<ReservationPreorderItem> items;
  final double subtotal;

  const ReservationPreorderGuest({
    required this.guestName,
    required this.items,
    required this.subtotal,
  });

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  @override
  List<Object?> get props => [guestName, items, subtotal];
}

/// Resumen completo del pre-pedido de una reserva — lo que el admin ve
/// en el detalle para revisar/confirmar antes de que llegue el grupo.
class ReservationPreorderSummary extends Equatable {
  final String reservationId;
  final String? preorderToken;
  final bool preorderOpen;
  final String? preorderUrl;
  final List<ReservationPreorderGuest> guests;
  final double total;

  const ReservationPreorderSummary({
    required this.reservationId,
    this.preorderToken,
    required this.preorderOpen,
    this.preorderUrl,
    required this.guests,
    required this.total,
  });

  bool get hasLink => preorderToken != null && preorderToken!.isNotEmpty;
  bool get isEmpty => guests.isEmpty;

  @override
  List<Object?> get props =>
      [reservationId, preorderToken, preorderOpen, preorderUrl, guests, total];
}

/// Link público (token + URL completa) para compartir con el grupo.
class ReservationPreorderLink extends Equatable {
  final String token;
  final String url;

  const ReservationPreorderLink({required this.token, required this.url});

  @override
  List<Object?> get props => [token, url];
}
