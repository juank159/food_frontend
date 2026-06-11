/// Modelo del item del endpoint `GET /qr-tokens/available-tables`.
///
/// Representa una mesa física del tenant (extraída de un floor plan)
/// con flag de si ya tiene QR asignado. Reemplaza el input de texto
/// libre por dropdown / lista de selección.
class AvailableTable {
  final String tableElementId;
  final String tableLabel;
  final String? tableCapacity;
  final String status; // available / occupied / etc
  final String floorPlanId;
  final String floorPlanName;
  final int floorLevel;
  final bool hasQr;
  final String? qrCode;
  final String? qrTokenId;
  final bool qrIsActive;

  const AvailableTable({
    required this.tableElementId,
    required this.tableLabel,
    required this.tableCapacity,
    required this.status,
    required this.floorPlanId,
    required this.floorPlanName,
    required this.floorLevel,
    required this.hasQr,
    required this.qrCode,
    required this.qrTokenId,
    required this.qrIsActive,
  });

  /// Label compuesto para mostrar al admin: "Mesa 1 · Terraza".
  String get displayLabel {
    if (floorPlanName.isEmpty) return tableLabel;
    return '$tableLabel · $floorPlanName';
  }

  factory AvailableTable.fromJson(Map<String, dynamic> json) {
    return AvailableTable(
      tableElementId: json['table_element_id'] as String,
      tableLabel: (json['table_label'] as String?) ?? 'Mesa',
      tableCapacity: json['table_capacity'] as String?,
      status: (json['status'] as String?) ?? 'available',
      floorPlanId: (json['floor_plan_id'] as String?) ?? '',
      floorPlanName: (json['floor_plan_name'] as String?) ?? '',
      floorLevel: (json['floor_level'] as num?)?.toInt() ?? 0,
      hasQr: json['has_qr'] as bool? ?? false,
      qrCode: json['qr_code'] as String?,
      qrTokenId: json['qr_token_id'] as String?,
      qrIsActive: json['qr_is_active'] as bool? ?? false,
    );
  }
}
