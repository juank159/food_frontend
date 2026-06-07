import 'package:equatable/equatable.dart';
import '../../../../core/config/constants/table_enums.dart';

/// Entidad que representa el estado de una mesa en tiempo real
class TableStatusEntity extends Equatable {
  final String id;
  final String floorPlanId;
  final String tableElementId;
  final TableStatus status;
  final String? currentOrderId;
  final String? reservationId;
  final String? serverId;
  final int? partySize;
  final String? tableCapacity;
  final String? tableLabel;
  final String? notes;
  final DateTime? occupiedAt;
  final DateTime? reservedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TableStatusEntity({
    required this.id,
    required this.floorPlanId,
    required this.tableElementId,
    required this.status,
    this.currentOrderId,
    this.reservationId,
    this.serverId,
    this.partySize,
    this.tableCapacity,
    this.tableLabel,
    this.notes,
    this.occupiedAt,
    this.reservedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        floorPlanId,
        tableElementId,
        status,
        currentOrderId,
        reservationId,
        serverId,
        partySize,
        tableCapacity,
        tableLabel,
        notes,
        occupiedAt,
        reservedAt,
        createdAt,
        updatedAt,
      ];

  TableStatusEntity copyWith({
    String? id,
    String? floorPlanId,
    String? tableElementId,
    TableStatus? status,
    String? currentOrderId,
    String? reservationId,
    String? serverId,
    int? partySize,
    String? tableCapacity,
    String? tableLabel,
    String? notes,
    DateTime? occupiedAt,
    DateTime? reservedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TableStatusEntity(
      id: id ?? this.id,
      floorPlanId: floorPlanId ?? this.floorPlanId,
      tableElementId: tableElementId ?? this.tableElementId,
      status: status ?? this.status,
      currentOrderId: currentOrderId ?? this.currentOrderId,
      reservationId: reservationId ?? this.reservationId,
      serverId: serverId ?? this.serverId,
      partySize: partySize ?? this.partySize,
      tableCapacity: tableCapacity ?? this.tableCapacity,
      tableLabel: tableLabel ?? this.tableLabel,
      notes: notes ?? this.notes,
      occupiedAt: occupiedAt ?? this.occupiedAt,
      reservedAt: reservedAt ?? this.reservedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'floorPlanId': floorPlanId,
      'tableElementId': tableElementId,
      'status': status.name,
      'currentOrderId': currentOrderId,
      'reservationId': reservationId,
      'serverId': serverId,
      'partySize': partySize,
      'tableCapacity': tableCapacity,
      'tableLabel': tableLabel,
      'notes': notes,
      'occupiedAt': occupiedAt?.toIso8601String(),
      'reservedAt': reservedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TableStatusEntity.fromJson(Map<String, dynamic> json) {
    return TableStatusEntity(
      id: json['id'] as String,
      floorPlanId: json['floorPlanId'] as String,
      tableElementId: json['tableElementId'] as String,
      status: TableStatus.fromString(json['status'] as String),
      currentOrderId: json['currentOrderId'] as String?,
      reservationId: json['reservationId'] as String?,
      serverId: json['serverId'] as String?,
      partySize: json['partySize'] as int?,
      tableCapacity: json['tableCapacity'] as String?,
      tableLabel: json['tableLabel'] as String?,
      notes: json['notes'] as String?,
      occupiedAt: json['occupiedAt'] != null
          ? DateTime.parse(json['occupiedAt'] as String)
          : null,
      reservedAt: json['reservedAt'] != null
          ? DateTime.parse(json['reservedAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Verifica si la mesa está disponible para ocupar
  bool get isAvailableToOccupy => status == TableStatus.available;

  /// Verifica si la mesa está ocupada
  bool get isOccupied => status == TableStatus.occupied;

  /// Verifica si la mesa está reservada
  bool get isReserved => status == TableStatus.reserved;

  /// Verifica si la mesa está en limpieza
  bool get isCleaning => status == TableStatus.cleaning;

  /// Verifica si la mesa está en mantenimiento
  bool get isInMaintenance => status == TableStatus.maintenance;

  /// Obtiene el tiempo que lleva la mesa ocupada (si aplica)
  Duration? get occupiedDuration {
    if (occupiedAt == null) return null;
    return DateTime.now().difference(occupiedAt!);
  }

  /// Obtiene el tiempo que lleva la mesa reservada (si aplica)
  Duration? get reservedDuration {
    if (reservedAt == null) return null;
    return DateTime.now().difference(reservedAt!);
  }
}
