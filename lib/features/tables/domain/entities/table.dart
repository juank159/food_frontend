import 'package:equatable/equatable.dart';
import '../../../../core/config/constants/table_enums.dart';

/// Table Entity
/// Entidad que representa una mesa en el restaurante
class RestaurantTable extends Equatable {
  final String id;
  final String tableNumber;
  final String? name;
  final int capacity;
  final int minCapacity;
  final TableStatus status;
  final TableType tableType;
  final TableShape? shape;
  final String? zone;
  final String? section;
  final bool isActive;
  final double positionX;
  final double positionY;
  final double width;
  final double height;
  final String shapeType; // 'circle', 'rectangle', 'square'
  final String? currentOrderId;
  final DateTime? occupiedSince;
  final String? assignedTo;
  final String? qrCode;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RestaurantTable({
    required this.id,
    required this.tableNumber,
    this.name,
    required this.capacity,
    this.minCapacity = 1,
    required this.status,
    this.tableType = TableType.standard,
    this.shape,
    this.zone,
    this.section,
    this.isActive = true,
    this.positionX = 0,
    this.positionY = 0,
    this.width = 80,
    this.height = 80,
    this.shapeType = 'circle',
    this.currentOrderId,
    this.occupiedSince,
    this.assignedTo,
    this.qrCode,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        tableNumber,
        name,
        capacity,
        minCapacity,
        status,
        tableType,
        shape,
        zone,
        section,
        isActive,
        positionX,
        positionY,
        width,
        height,
        shapeType,
        currentOrderId,
        occupiedSince,
        assignedTo,
        qrCode,
        metadata,
        createdAt,
        updatedAt,
      ];

  // Business logic helpers
  bool get isAvailable => status == TableStatus.available && isActive;
  bool get isOccupied => status == TableStatus.occupied;
  bool get isReserved => status == TableStatus.reserved;
  bool get hasActiveOrder => currentOrderId != null && currentOrderId!.isNotEmpty;
  bool get canBeOccupied => status.isAvailableForOrders && isActive;
  bool get requiresCleaning => status == TableStatus.cleaning;

  String get displayName => name ?? 'Mesa $tableNumber';

  String get statusDisplay {
    if (!isActive) return 'Inactiva';
    return status.displayName;
  }

  // Duración de ocupación
  Duration? get occupationDuration {
    if (occupiedSince == null) return null;
    return DateTime.now().difference(occupiedSince!);
  }

  // Formato de duración de ocupación
  String get occupationDurationFormatted {
    final duration = occupationDuration;
    if (duration == null) return '-';

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  // Copy with
  RestaurantTable copyWith({
    String? id,
    String? tableNumber,
    String? name,
    int? capacity,
    int? minCapacity,
    TableStatus? status,
    TableType? tableType,
    TableShape? shape,
    String? zone,
    String? section,
    bool? isActive,
    double? positionX,
    double? positionY,
    double? width,
    double? height,
    String? shapeType,
    String? currentOrderId,
    DateTime? occupiedSince,
    String? assignedTo,
    String? qrCode,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RestaurantTable(
      id: id ?? this.id,
      tableNumber: tableNumber ?? this.tableNumber,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      minCapacity: minCapacity ?? this.minCapacity,
      status: status ?? this.status,
      tableType: tableType ?? this.tableType,
      shape: shape ?? this.shape,
      zone: zone ?? this.zone,
      section: section ?? this.section,
      isActive: isActive ?? this.isActive,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      width: width ?? this.width,
      height: height ?? this.height,
      shapeType: shapeType ?? this.shapeType,
      currentOrderId: currentOrderId ?? this.currentOrderId,
      occupiedSince: occupiedSince ?? this.occupiedSince,
      assignedTo: assignedTo ?? this.assignedTo,
      qrCode: qrCode ?? this.qrCode,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
