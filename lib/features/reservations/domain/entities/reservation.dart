import 'package:equatable/equatable.dart';
import '../../../../core/config/constants/reservation_enums.dart';

/// Reservation Entity
///
/// Entidad de dominio para reservas de mesa. Mapea 1:1 con la tabla
/// `reservations` del backend (multitenant). Una reserva puede ser:
///   - "registrada": vinculada a un Customer (`customerId` no nulo).
///   - "walk-in": solo `customerName` + datos opcionales.
class Reservation extends Equatable {
  final String id;
  final String? customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerEmail;
  final int partySize;
  final DateTime reservedFor;
  final int durationMinutes;
  final String? tableElementId;
  final String? floorPlanId;
  final ReservationStatus status;
  final String? notes;
  final String createdBy;
  final DateTime? confirmedAt;
  final DateTime? seatedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Reservation({
    required this.id,
    this.customerId,
    required this.customerName,
    this.customerPhone,
    this.customerEmail,
    required this.partySize,
    required this.reservedFor,
    this.durationMinutes = 90,
    this.tableElementId,
    this.floorPlanId,
    this.status = ReservationStatus.pending,
    this.notes,
    required this.createdBy,
    this.confirmedAt,
    this.seatedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  // ─────────────────────────── Status helpers ───────────────────────────

  bool get isPending => status == ReservationStatus.pending;
  bool get isConfirmed => status == ReservationStatus.confirmed;
  bool get isSeated => status == ReservationStatus.seated;
  bool get isCompleted => status == ReservationStatus.completed;
  bool get isCancelled => status == ReservationStatus.cancelled;
  bool get isNoShow => status == ReservationStatus.noShow;

  /// Estado terminal (completed/no_show/cancelled).
  bool get isTerminal => status.isTerminal;

  /// La reserva todavía está "viva".
  bool get isActive => status.isActive;

  // ─────────────────────────── Time helpers ───────────────────────────

  /// `true` si `reservedFor` está en el futuro.
  bool get isUpcoming => reservedFor.isAfter(DateTime.now());

  /// `true` si `reservedFor` ya pasó.
  bool get isPast => reservedFor.isBefore(DateTime.now());

  /// `true` si la reserva es para hoy (mismo día calendario).
  bool get isToday {
    final now = DateTime.now();
    return reservedFor.year == now.year &&
        reservedFor.month == now.month &&
        reservedFor.day == now.day;
  }

  /// `true` si la reserva es dentro de las próximas 24 horas Y todavía
  /// no llegó. Útil para el filtro "Próximas".
  bool get isWithinNext24Hours {
    if (!isUpcoming) return false;
    return reservedFor.difference(DateTime.now()).inHours <= 24;
  }

  /// `true` si la reserva pasó hace más de 30 min y sigue en `pending`
  /// o `confirmed` — la host debería marcarla como no_show o seated.
  bool get isOverdue {
    if (isTerminal || isSeated) return false;
    final diff = DateTime.now().difference(reservedFor);
    return diff.inMinutes > 30;
  }

  /// Duración + reservedFor → momento estimado de finalización.
  DateTime get estimatedEndTime =>
      reservedFor.add(Duration(minutes: durationMinutes));

  /// Diferencia firmada (positivo = futuro, negativo = pasado).
  Duration get timeUntilReservation =>
      reservedFor.difference(DateTime.now());

  // ─────────────────────────── Display helpers ───────────────────────────

  /// Iniciales para el avatar (máx 2 letras).
  String get initials {
    final parts = customerName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// `true` si la reserva tiene mesa pre-asignada.
  bool get hasTable =>
      tableElementId != null && tableElementId!.isNotEmpty;

  Reservation copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    int? partySize,
    DateTime? reservedFor,
    int? durationMinutes,
    String? tableElementId,
    String? floorPlanId,
    ReservationStatus? status,
    String? notes,
    String? createdBy,
    DateTime? confirmedAt,
    DateTime? seatedAt,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Reservation(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      partySize: partySize ?? this.partySize,
      reservedFor: reservedFor ?? this.reservedFor,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      tableElementId: tableElementId ?? this.tableElementId,
      floorPlanId: floorPlanId ?? this.floorPlanId,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      seatedAt: seatedAt ?? this.seatedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        customerId,
        customerName,
        customerPhone,
        customerEmail,
        partySize,
        reservedFor,
        durationMinutes,
        tableElementId,
        floorPlanId,
        status,
        notes,
        createdBy,
        confirmedAt,
        seatedAt,
        completedAt,
        createdAt,
        updatedAt,
      ];
}
