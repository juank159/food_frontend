// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'table_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TableModel _$TableModelFromJson(Map<String, dynamic> json) => TableModel(
  id: json['id'] as String?,
  tableNumber: json['table_number'] as String,
  name: json['name'] as String?,
  capacity: (json['capacity'] as num).toInt(),
  minCapacity: (json['min_capacity'] as num?)?.toInt(),
  status: json['status'] as String,
  tableType: json['table_type'] as String?,
  shape: json['shape'] as String?,
  zone: _zoneFromJson(json['zone']),
  section: json['section'] as String?,
  isActive: json['is_active'] as bool?,
  positionX: JsonParsers.parseNullableDouble(json['position_x']),
  positionY: JsonParsers.parseNullableDouble(json['position_y']),
  width: JsonParsers.parseNullableDouble(json['width']),
  height: JsonParsers.parseNullableDouble(json['height']),
  shapeType: json['shape_type'] as String?,
  currentOrderId: json['current_order_id'] as String?,
  occupiedSince: json['occupied_since'] == null
      ? null
      : DateTime.parse(json['occupied_since'] as String),
  assignedTo: json['assigned_to'] as String?,
  qrCode: json['qr_code'] as String?,
  metadata: json['metadata'] as Map<String, dynamic>?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$TableModelToJson(TableModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'table_number': instance.tableNumber,
      'name': instance.name,
      'capacity': instance.capacity,
      'min_capacity': instance.minCapacity,
      'status': instance.status,
      'table_type': instance.tableType,
      'shape': instance.shape,
      'zone': instance.zone,
      'section': instance.section,
      'is_active': instance.isActive,
      'position_x': instance.positionX,
      'position_y': instance.positionY,
      'width': instance.width,
      'height': instance.height,
      'shape_type': instance.shapeType,
      'current_order_id': instance.currentOrderId,
      'occupied_since': instance.occupiedSince?.toIso8601String(),
      'assigned_to': instance.assignedTo,
      'qr_code': instance.qrCode,
      'metadata': instance.metadata,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
