library;

/// Reservation Enums
/// Enumeraciones para el módulo de reservaciones (mesas reservadas).

/// Estado de una reservación.
///
/// Las transiciones válidas (definidas también en el backend) son:
///   - pending   → confirmed | cancelled | no_show
///   - confirmed → seated    | cancelled | no_show
///   - seated    → completed | cancelled
///   - completed | no_show | cancelled → terminales (no más cambios)
enum ReservationStatus {
  pending('pending', 'Pendiente'),
  confirmed('confirmed', 'Confirmada'),
  seated('seated', 'Sentada'),
  completed('completed', 'Completada'),
  noShow('no_show', 'No se presentó'),
  cancelled('cancelled', 'Cancelada');

  final String value;
  final String displayName;

  const ReservationStatus(this.value, this.displayName);

  static ReservationStatus fromString(String value) {
    return ReservationStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ReservationStatus.pending,
    );
  }

  /// Estado terminal: no admite más transiciones.
  bool get isTerminal =>
      this == ReservationStatus.completed ||
      this == ReservationStatus.noShow ||
      this == ReservationStatus.cancelled;

  /// Reservación todavía "viva" (no terminada ni cancelada).
  bool get isActive => !isTerminal;

  /// Próximas transiciones válidas desde el estado actual.
  /// La UI usa esto para construir los botones de acción.
  List<ReservationStatus> get nextTransitions {
    switch (this) {
      case ReservationStatus.pending:
        return [
          ReservationStatus.confirmed,
          ReservationStatus.cancelled,
          ReservationStatus.noShow,
        ];
      case ReservationStatus.confirmed:
        return [
          ReservationStatus.seated,
          ReservationStatus.cancelled,
          ReservationStatus.noShow,
        ];
      case ReservationStatus.seated:
        return [
          ReservationStatus.completed,
          ReservationStatus.cancelled,
        ];
      case ReservationStatus.completed:
      case ReservationStatus.noShow:
      case ReservationStatus.cancelled:
        return const [];
    }
  }
}
