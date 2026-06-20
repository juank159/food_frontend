import '../../../../core/config/constants/reservation_enums.dart';
import '../../domain/entities/reservation.dart';

/// Reservation Model
///
/// Mapea la respuesta del backend (`reservations`) a la entidad de dominio.
/// Hand-written para tolerar el wire format real:
///   - `reserved_for` es timestamptz ISO8601 (UTC).
///   - Los timestamps de auditoría son nullables (sólo se setean al
///     transicionar el status).
class ReservationModel {
  final String id;
  final String? customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerEmail;
  final int partySize;
  final String reservedFor;
  final int durationMinutes;
  final String? tableElementId;
  final String? floorPlanId;
  final String status;
  final String? notes;
  final String createdBy;
  final String? confirmedAt;
  final String? seatedAt;
  final String? completedAt;
  final String createdAt;
  final String updatedAt;

  const ReservationModel({
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
    this.status = 'pending',
    this.notes,
    required this.createdBy,
    this.confirmedAt,
    this.seatedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Reservation toEntity() {
    return Reservation(
      id: id,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      partySize: partySize,
      reservedFor: DateTime.parse(reservedFor).toLocal(),
      durationMinutes: durationMinutes,
      tableElementId: tableElementId,
      floorPlanId: floorPlanId,
      status: ReservationStatus.fromString(status),
      notes: notes,
      createdBy: createdBy,
      confirmedAt:
          confirmedAt != null ? DateTime.parse(confirmedAt!).toLocal() : null,
      seatedAt: seatedAt != null ? DateTime.parse(seatedAt!).toLocal() : null,
      completedAt:
          completedAt != null ? DateTime.parse(completedAt!).toLocal() : null,
      createdAt: DateTime.parse(createdAt).toLocal(),
      updatedAt: DateTime.parse(updatedAt).toLocal(),
    );
  }

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    return ReservationModel(
      id: json['id'] as String,
      customerId: json['customer_id'] as String?,
      customerName: json['customer_name'] as String,
      customerPhone: json['customer_phone'] as String?,
      customerEmail: json['customer_email'] as String?,
      partySize: (json['party_size'] as num?)?.toInt() ?? 1,
      reservedFor: json['reserved_for'] as String,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 90,
      tableElementId: json['table_element_id'] as String?,
      floorPlanId: json['floor_plan_id'] as String?,
      status: (json['status'] as String?) ?? 'pending',
      notes: json['notes'] as String?,
      createdBy: (json['created_by'] as String?) ?? '',
      confirmedAt: json['confirmed_at'] as String?,
      seatedAt: json['seated_at'] as String?,
      completedAt: json['completed_at'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }
}
