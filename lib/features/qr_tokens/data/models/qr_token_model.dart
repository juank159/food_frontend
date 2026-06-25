/// Tipo del QR (matchea con el enum `QrTokenType` del backend).
enum QrTokenType {
  table('table', 'Mesa específica'),
  zone('zone', 'Zona / Área'),
  pickup('pickup', 'Pickup / Mostrador'),
  generic('generic', 'Barra / Mostrador');

  final String apiValue;
  final String displayName;

  const QrTokenType(this.apiValue, this.displayName);

  static QrTokenType fromString(String value) {
    return QrTokenType.values.firstWhere(
      (t) => t.apiValue == value,
      orElse: () => QrTokenType.generic,
    );
  }
}

/// QR token tal como lo expone la API. Inmutable — para editar se
/// llama el endpoint update y reemplaza la instancia en la lista del
/// controller (no se mutan campos in-place).
class QrTokenModel {
  final String id;
  final String code;
  final QrTokenType type;
  final String displayLabel;
  final String? tableElementId;
  final String? zoneLabel;
  final bool isActive;
  final int scanCount;
  final DateTime? lastScannedAt;
  final DateTime createdAt;

  const QrTokenModel({
    required this.id,
    required this.code,
    required this.type,
    required this.displayLabel,
    this.tableElementId,
    this.zoneLabel,
    required this.isActive,
    required this.scanCount,
    this.lastScannedAt,
    required this.createdAt,
  });

  factory QrTokenModel.fromJson(Map<String, dynamic> json) {
    return QrTokenModel(
      id: json['id'] as String,
      code: json['code'] as String,
      type: QrTokenType.fromString(json['type'] as String? ?? 'generic'),
      displayLabel: json['display_label'] as String? ?? '',
      tableElementId: json['table_element_id'] as String?,
      zoneLabel: json['zone_label'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      scanCount: (json['scan_count'] as num?)?.toInt() ?? 0,
      lastScannedAt: json['last_scanned_at'] == null
          ? null
          : DateTime.tryParse(json['last_scanned_at'] as String),
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
