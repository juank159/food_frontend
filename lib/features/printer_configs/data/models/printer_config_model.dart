/// Propósito de la impresora (matchea con el enum del backend).
enum PrinterPurpose {
  kitchen('kitchen', 'Cocina · Comanda'),
  receipt('receipt', 'Caja · Recibo'),
  both('both', 'Ambos (cocina + recibo)');

  final String apiValue;
  final String displayName;

  const PrinterPurpose(this.apiValue, this.displayName);

  static PrinterPurpose fromString(String value) =>
      PrinterPurpose.values.firstWhere(
        (p) => p.apiValue == value,
        orElse: () => PrinterPurpose.receipt,
      );
}

/// Cómo se conecta la app a la impresora.
enum PrinterConnectionType {
  /// Diálogo nativo del SO (CUPS / Windows / AirPrint).
  /// Setup CERO pero requiere confirmación humana en cada impresión.
  system('system', 'Impresora del sistema'),

  /// TCP raw a IP:9100 — imprime sin diálogo, ideal para auto-print.
  /// Requiere impresora con Ethernet/WiFi y IP fija en la LAN.
  network('network', 'Impresora en red (IP)');

  final String apiValue;
  final String displayName;

  const PrinterConnectionType(this.apiValue, this.displayName);

  static PrinterConnectionType fromString(String value) =>
      PrinterConnectionType.values.firstWhere(
        (c) => c.apiValue == value,
        orElse: () => PrinterConnectionType.system,
      );
}

class PrinterConfigModel {
  final String id;
  final String name;
  final PrinterPurpose purpose;
  final PrinterConnectionType connectionType;
  final String? host;
  final int? port;
  final int paperWidth; // 58 | 80
  final bool isDefault;
  final bool autoPrint;
  final bool isActive;
  final String? notes;

  /// Roles que pueden imprimir. Vacío = todos los roles.
  final List<String> allowedRoles;

  const PrinterConfigModel({
    required this.id,
    required this.name,
    required this.purpose,
    required this.connectionType,
    required this.host,
    required this.port,
    required this.paperWidth,
    required this.isDefault,
    required this.autoPrint,
    required this.isActive,
    required this.notes,
    this.allowedRoles = const [],
  });

  String get connectionSummary {
    if (connectionType == PrinterConnectionType.system) {
      return 'Impresora del sistema · ${paperWidth}mm';
    }
    return '${host ?? '?'}:${port ?? 9100} · ${paperWidth}mm';
  }

  bool get coversPurpose => true; // helper para UI futura

  /// True si esta impresora puede atender el propósito dado (matchea
  /// exacto o es `both`).
  bool servesPurpose(PrinterPurpose target) {
    return purpose == target || purpose == PrinterPurpose.both;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'purpose': purpose.apiValue,
        'connection_type': connectionType.apiValue,
        'host': host,
        'port': port,
        'paper_width': paperWidth,
        'is_default': isDefault,
        'auto_print': autoPrint,
        'is_active': isActive,
        'notes': notes,
        'allowed_roles': allowedRoles.isEmpty ? null : allowedRoles.join(','),
      };

  factory PrinterConfigModel.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['allowed_roles'] as String?;
    final roles = (rawRoles != null && rawRoles.trim().isNotEmpty)
        ? rawRoles.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : <String>[];
    return PrinterConfigModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      purpose: PrinterPurpose.fromString(json['purpose'] as String? ?? 'receipt'),
      connectionType: PrinterConnectionType.fromString(
        json['connection_type'] as String? ?? 'system',
      ),
      host: json['host'] as String?,
      port: (json['port'] as num?)?.toInt(),
      paperWidth: (json['paper_width'] as num?)?.toInt() ?? 80,
      isDefault: json['is_default'] as bool? ?? false,
      autoPrint: json['auto_print'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      notes: json['notes'] as String?,
      allowedRoles: roles,
    );
  }
}
