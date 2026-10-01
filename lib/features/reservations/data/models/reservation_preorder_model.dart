import '../../domain/entities/reservation_preorder.dart';

num _asNum(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;

class ReservationPreorderLinkModel {
  final String token;
  final String url;

  const ReservationPreorderLinkModel({required this.token, required this.url});

  factory ReservationPreorderLinkModel.fromJson(Map<String, dynamic> json) {
    return ReservationPreorderLinkModel(
      token: json['token'] as String,
      url: json['url'] as String,
    );
  }

  ReservationPreorderLink toEntity() =>
      ReservationPreorderLink(token: token, url: url);
}

class ReservationPreorderItemModel {
  final String? id;
  final String productName;
  final String? variantName;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final String? notes;

  const ReservationPreorderItemModel({
    this.id,
    required this.productName,
    this.variantName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.notes,
  });

  factory ReservationPreorderItemModel.fromJson(Map<String, dynamic> json) {
    final unitPrice = _asNum(json['unit_price']).toDouble();
    final quantity = (json['quantity'] as num?)?.toInt() ?? 1;
    return ReservationPreorderItemModel(
      id: json['id'] as String?,
      productName: json['product_name'] as String? ?? '',
      variantName: json['variant_name'] as String?,
      quantity: quantity,
      unitPrice: unitPrice,
      subtotal: json['subtotal'] != null
          ? _asNum(json['subtotal']).toDouble()
          : unitPrice * quantity,
      notes: json['notes'] as String?,
    );
  }

  ReservationPreorderItem toEntity() => ReservationPreorderItem(
        id: id,
        productName: productName,
        variantName: variantName,
        quantity: quantity,
        unitPrice: unitPrice,
        subtotal: subtotal,
        notes: notes,
      );
}

class ReservationPreorderGuestModel {
  final String guestName;
  final List<ReservationPreorderItemModel> items;
  final double subtotal;

  const ReservationPreorderGuestModel({
    required this.guestName,
    required this.items,
    required this.subtotal,
  });

  factory ReservationPreorderGuestModel.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .map((e) => ReservationPreorderItemModel.fromJson(
              e as Map<String, dynamic>,
            ))
        .toList();
    return ReservationPreorderGuestModel(
      guestName: json['guest_name'] as String? ?? '',
      items: items,
      subtotal: json['subtotal'] != null
          ? _asNum(json['subtotal']).toDouble()
          : items.fold(0.0, (sum, i) => sum + i.subtotal),
    );
  }

  ReservationPreorderGuest toEntity() => ReservationPreorderGuest(
        guestName: guestName,
        items: items.map((i) => i.toEntity()).toList(),
        subtotal: subtotal,
      );
}

class ReservationPreorderSummaryModel {
  final String reservationId;
  final String? preorderToken;
  final bool preorderOpen;
  final String? preorderUrl;
  final List<ReservationPreorderGuestModel> guests;
  final double total;

  const ReservationPreorderSummaryModel({
    required this.reservationId,
    this.preorderToken,
    required this.preorderOpen,
    this.preorderUrl,
    required this.guests,
    required this.total,
  });

  factory ReservationPreorderSummaryModel.fromJson(Map<String, dynamic> json) {
    final guests = (json['guests'] as List<dynamic>? ?? [])
        .map((e) => ReservationPreorderGuestModel.fromJson(
              e as Map<String, dynamic>,
            ))
        .toList();
    return ReservationPreorderSummaryModel(
      reservationId: json['reservation_id'] as String? ?? '',
      preorderToken: json['preorder_token'] as String?,
      preorderOpen: json['preorder_open'] as bool? ?? true,
      preorderUrl: json['preorder_url'] as String?,
      guests: guests,
      total: json['total'] != null
          ? _asNum(json['total']).toDouble()
          : guests.fold(0.0, (sum, g) => sum + g.subtotal),
    );
  }

  ReservationPreorderSummary toEntity() => ReservationPreorderSummary(
        reservationId: reservationId,
        preorderToken: preorderToken,
        preorderOpen: preorderOpen,
        preorderUrl: preorderUrl,
        guests: guests.map((g) => g.toEntity()).toList(),
        total: total,
      );
}
