import 'package:equatable/equatable.dart';

/// DTO para crear o actualizar el estado de una mesa
class CreateTableStatusDto extends Equatable {
  final String floorPlanId;
  final String tableElementId;
  final String? status;
  final String? serverId;
  final int? partySize;
  final String? notes;
  final String? tableCapacity;
  final String? tableLabel;

  const CreateTableStatusDto({
    required this.floorPlanId,
    required this.tableElementId,
    this.status,
    this.serverId,
    this.partySize,
    this.notes,
    this.tableCapacity,
    this.tableLabel,
  });

  @override
  List<Object?> get props => [
        floorPlanId,
        tableElementId,
        status,
        serverId,
        partySize,
        notes,
        tableCapacity,
        tableLabel,
      ];

  Map<String, dynamic> toJson() {
    return {
      'floorPlanId': floorPlanId,
      'tableElementId': tableElementId,
      if (status != null) 'status': status,
      if (serverId != null) 'serverId': serverId,
      if (partySize != null) 'partySize': partySize,
      if (notes != null) 'notes': notes,
      if (tableCapacity != null) 'tableCapacity': tableCapacity,
      if (tableLabel != null) 'tableLabel': tableLabel,
    };
  }
}

/// DTO para actualizar el estado de una mesa existente
class UpdateTableStatusDto extends Equatable {
  final String? status;
  final String? currentOrderId;
  final String? reservationId;
  final String? serverId;
  final int? partySize;
  final String? notes;

  const UpdateTableStatusDto({
    this.status,
    this.currentOrderId,
    this.reservationId,
    this.serverId,
    this.partySize,
    this.notes,
  });

  @override
  List<Object?> get props => [
        status,
        currentOrderId,
        reservationId,
        serverId,
        partySize,
        notes,
      ];

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (status != null) map['status'] = status;
    if (currentOrderId != null) map['currentOrderId'] = currentOrderId;
    if (reservationId != null) map['reservationId'] = reservationId;
    if (serverId != null) map['serverId'] = serverId;
    if (partySize != null) map['partySize'] = partySize;
    if (notes != null) map['notes'] = notes;
    return map;
  }
}

/// DTO para ocupar una mesa
class OccupyTableDto extends Equatable {
  final int partySize;
  final String? serverId;
  final String? notes;

  const OccupyTableDto({
    required this.partySize,
    this.serverId,
    this.notes,
  });

  @override
  List<Object?> get props => [partySize, serverId, notes];

  Map<String, dynamic> toJson() {
    return {
      'partySize': partySize,
      if (serverId != null) 'serverId': serverId,
      if (notes != null) 'notes': notes,
    };
  }
}

/// DTO para reservar una mesa
class ReserveTableDto extends Equatable {
  final int partySize;
  final String? reservationId;
  final DateTime? reservedFor;
  final String? notes;

  const ReserveTableDto({
    required this.partySize,
    this.reservationId,
    this.reservedFor,
    this.notes,
  });

  @override
  List<Object?> get props => [partySize, reservationId, reservedFor, notes];

  Map<String, dynamic> toJson() {
    return {
      'partySize': partySize,
      if (reservationId != null) 'reservationId': reservationId,
      if (reservedFor != null) 'reservedFor': reservedFor!.toIso8601String(),
      if (notes != null) 'notes': notes,
    };
  }
}
