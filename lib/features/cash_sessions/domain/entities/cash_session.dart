import 'package:equatable/equatable.dart';

enum CashSessionStatus {
  open('open', 'Abierta'),
  closed('closed', 'Cerrada'),
  voided('void', 'Anulada');

  final String value;
  final String displayName;

  const CashSessionStatus(this.value, this.displayName);

  static CashSessionStatus fromString(String v) =>
      CashSessionStatus.values.firstWhere(
        (s) => s.value == v,
        orElse: () => CashSessionStatus.open,
      );
}

/// Sesión de caja registradora.
class CashSession extends Equatable {
  final String id;
  final String openedBy;
  final String? openedByName;
  final DateTime openedAt;
  final double openingAmount;

  final String? closedBy;
  final String? closedByName;
  final DateTime? closedAt;
  final double? closingAmountCounted;

  final double totalCashCollected;
  final int totalPaymentsCount;
  final double? expectedAmount;
  final double? difference;

  final CashSessionStatus status;
  final String? notes;
  final String? closingNotes;

  const CashSession({
    required this.id,
    required this.openedBy,
    this.openedByName,
    required this.openedAt,
    required this.openingAmount,
    this.closedBy,
    this.closedByName,
    this.closedAt,
    this.closingAmountCounted,
    required this.totalCashCollected,
    required this.totalPaymentsCount,
    this.expectedAmount,
    this.difference,
    required this.status,
    this.notes,
    this.closingNotes,
  });

  bool get isOpen => status == CashSessionStatus.open;
  bool get isClosed => status == CashSessionStatus.closed;
  bool get isVoided => status == CashSessionStatus.voided;

  /// True si la caja está abierta Y se abrió en un día diferente al de hoy
  /// (hora local del dispositivo). Indica turno olvidado del día anterior.
  bool get isFromPreviousDay {
    if (!isOpen) return false;
    final now = DateTime.now();
    final opened = openedAt.toLocal();
    return opened.year != now.year ||
        opened.month != now.month ||
        opened.day != now.day;
  }

  /// Monto esperado en vivo (para sesiones abiertas: opening + cash
  /// collected; para cerradas: el snapshot almacenado).
  double get currentExpectedAmount =>
      expectedAmount ?? (openingAmount + totalCashCollected);

  /// Diferencia "qué tan lejos del cuadre estamos" — solo útil para
  /// sesiones ya cerradas. Null en sesiones abiertas.
  bool get hasDifference => difference != null && difference!.abs() > 0.01;

  /// Duración del turno en minutos, si está cerrada.
  int? get durationMinutes {
    if (closedAt == null) return null;
    return closedAt!.difference(openedAt).inMinutes;
  }

  @override
  List<Object?> get props => [
        id,
        openedBy,
        openedByName,
        openedAt,
        openingAmount,
        closedBy,
        closedByName,
        closedAt,
        closingAmountCounted,
        totalCashCollected,
        totalPaymentsCount,
        expectedAmount,
        difference,
        status,
        notes,
        closingNotes,
      ];
}
