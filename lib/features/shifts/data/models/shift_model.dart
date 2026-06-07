import '../../domain/entities/shift.dart';

/// Modelo de Shift. fromJson tolerante porque el backend puede expandir
/// `user` como objeto anidado o no (TypeORM relations).
class ShiftModel {
  final String id;
  final String userId;
  final String? userName;
  final String clockIn;
  final String? clockOut;
  final int? durationMinutes;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  const ShiftModel({
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

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    // user puede venir como string (id) o como objeto expandido.
    final userRaw = json['user'];
    String? userName;
    if (userRaw is Map<String, dynamic>) {
      userName = (userRaw['full_name'] ?? userRaw['email']) as String?;
    }

    return ShiftModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userName: userName,
      clockIn: json['clock_in'] as String,
      clockOut: json['clock_out'] as String?,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Shift toEntity() => Shift(
        id: id,
        userId: userId,
        userName: userName,
        clockIn: DateTime.parse(clockIn),
        clockOut: clockOut != null ? DateTime.parse(clockOut!) : null,
        durationMinutes: durationMinutes,
        notes: notes,
        createdAt: DateTime.parse(createdAt),
        updatedAt: DateTime.parse(updatedAt),
      );
}
