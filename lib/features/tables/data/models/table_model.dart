import 'package:json_annotation/json_annotation.dart';
import '../../../../core/config/constants/table_enums.dart';
import '../../domain/entities/table.dart';
import '../../../../core/utils/json_parsers.dart';

part 'table_model.g.dart';

/// Helper function to extract zone name from zone object or string
String? _zoneFromJson(dynamic zone) {
  if (zone == null) return null;
  if (zone is String) return zone;
  if (zone is Map<String, dynamic>) {
    return zone['name'] as String?;
  }
  return null;
}

/// Table Model
/// Modelo para serialización JSON de mesas
@JsonSerializable(explicitToJson: true)
class TableModel {
  @JsonKey(name: 'id')
  final String? id;

  @JsonKey(name: 'table_number')
  final String tableNumber;

  final String? name;

  final int capacity;

  @JsonKey(name: 'min_capacity')
  final int? minCapacity;

  final String status;

  @JsonKey(name: 'table_type')
  final String? tableType;

  final String? shape;

  @JsonKey(name: 'zone', fromJson: _zoneFromJson)
  final String? zone;

  final String? section;

  @JsonKey(name: 'is_active')
  final bool? isActive;

  @JsonKey(name: 'position_x', fromJson: JsonParsers.parseNullableDouble)
  final double? positionX;

  @JsonKey(name: 'position_y', fromJson: JsonParsers.parseNullableDouble)
  final double? positionY;

  @JsonKey(fromJson: JsonParsers.parseNullableDouble)
  final double? width;

  @JsonKey(fromJson: JsonParsers.parseNullableDouble)
  final double? height;

  @JsonKey(name: 'shape_type')
  final String? shapeType;

  @JsonKey(name: 'current_order_id')
  final String? currentOrderId;

  @JsonKey(name: 'occupied_since')
  final DateTime? occupiedSince;

  @JsonKey(name: 'assigned_to')
  final String? assignedTo;

  @JsonKey(name: 'qr_code')
  final String? qrCode;

  final Map<String, dynamic>? metadata;

  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const TableModel({
    this.id,
    required this.tableNumber,
    this.name,
    required this.capacity,
    this.minCapacity,
    required this.status,
    this.tableType,
    this.shape,
    this.zone,
    this.section,
    this.isActive,
    this.positionX,
    this.positionY,
    this.width,
    this.height,
    this.shapeType,
    this.currentOrderId,
    this.occupiedSince,
    this.assignedTo,
    this.qrCode,
    this.metadata,
    this.createdAt,
    this.updatedAt,
  });

  factory TableModel.fromJson(Map<String, dynamic> json) =>
      _$TableModelFromJson(json);

  Map<String, dynamic> toJson() => _$TableModelToJson(this);

  /// Convierte el modelo a entidad de dominio
  RestaurantTable toEntity() {
    return RestaurantTable(
      id: id ?? '',
      tableNumber: tableNumber,
      name: name,
      capacity: capacity,
      minCapacity: minCapacity ?? 1,
      status: TableStatus.fromString(status),
      tableType: tableType != null
          ? TableType.fromString(tableType!)
          : TableType.standard,
      shape: shape != null ? TableShape.fromString(shape!) : null,
      zone: zone,
      section: section,
      isActive: isActive ?? true,
      positionX: positionX ?? 0,
      positionY: positionY ?? 0,
      width: width ?? 80,
      height: height ?? 80,
      shapeType: shapeType ?? 'circle',
      currentOrderId: currentOrderId,
      occupiedSince: occupiedSince,
      assignedTo: assignedTo,
      qrCode: qrCode,
      metadata: metadata,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Crea un modelo desde la entidad de dominio
  factory TableModel.fromEntity(RestaurantTable table) {
    return TableModel(
      id: table.id,
      tableNumber: table.tableNumber,
      name: table.name,
      capacity: table.capacity,
      minCapacity: table.minCapacity,
      status: table.status.value,
      tableType: table.tableType.value,
      shape: table.shape?.value,
      zone: table.zone,
      section: table.section,
      isActive: table.isActive,
      positionX: table.positionX,
      positionY: table.positionY,
      width: table.width,
      height: table.height,
      shapeType: table.shapeType,
      currentOrderId: table.currentOrderId,
      occupiedSince: table.occupiedSince,
      assignedTo: table.assignedTo,
      qrCode: table.qrCode,
      metadata: table.metadata,
      createdAt: table.createdAt,
      updatedAt: table.updatedAt,
    );
  }
}
