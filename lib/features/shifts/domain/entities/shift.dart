import 'package:equatable/equatable.dart';

/// Turno laboral de un empleado.
///
/// Modelo simple: clock_in marca entrada, clock_out (nullable) marca
/// salida. Mientras `clockOut == null`, el turno está abierto. El
/// backend calcula `durationMinutes` al cerrarse.
class Shift extends Equatable {
  final String id;
  final String userId;
  final String? userName;
  final DateTime clockIn;
  final DateTime? clockOut;
  final int? durationMinutes;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Shift({
    required this.id,
    required this.userId,
    this.userName,
    required this.clockIn,
    this.clockOut,
    this.durationMinutes,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// True si el turno está abierto (sin clock-out).
  bool get isOpen => clockOut == null;

  /// Duración en minutos. Si está cerrado usa el snapshot;
  /// si está abierto calcula en vivo desde `clockIn`.
  int get effectiveDurationMinutes {
    if (durationMinutes != null) return durationMinutes!;
    return DateTime.now().difference(clockIn).inMinutes;
  }

  /// "3h 24min" / "45 min" — para mostrar en cards.
  String get formattedDuration {
    final m = effectiveDurationMinutes;
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? '${h}h' : '${h}h ${rem}min';
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        userName,
        clockIn,
        clockOut,
        durationMinutes,
        notes,
        createdAt,
        updatedAt,
      ];
}
