import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/order_item.dart';
import 'order_item_modifier_model.dart';
import '../../../../core/utils/json_parsers.dart';

part 'order_item_model.g.dart';

/// Order Item Model
/// Modelo de datos para serialización JSON de items de orden
@JsonSerializable(createFactory: false)
class OrderItemModel {
  final String id;
  @JsonKey(name: 'order_id')
  final String orderId;
  @JsonKey(name: 'product_id')
  final String productId;
  @JsonKey(name: 'product_name')
  final String productName;
  @JsonKey(name: 'unit_price', fromJson: JsonParsers.parseDouble)
  final double unitPrice;
  final int quantity;
  @JsonKey(fromJson: JsonParsers.parseDouble)
  final double subtotal;
  @JsonKey(name: 'special_instructions')
  final String? specialInstructions;
  final Map<String, dynamic>? customizations;
  final List<OrderItemModifierModel>? modifiers;
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'updated_at')
  final String updatedAt;

  const OrderItemModel({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
    this.specialInstructions,
    this.customizations,
    this.modifiers,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convierte el modelo a entidad de dominio
  OrderItem toEntity() {
    return OrderItem(
      id: id,
      orderId: orderId,
      productId: productId,
      productName: productName,
      unitPrice: unitPrice,
      quantity: quantity,
      subtotal: subtotal,
      specialInstructions: specialInstructions,
      customizations: customizations,
      modifiers: modifiers?.map((m) => m.toEntity()).toList() ?? [],
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }

  /// Crea un modelo desde una entidad de dominio
  factory OrderItemModel.fromEntity(OrderItem item) {
    return OrderItemModel(
      id: item.id,
      orderId: item.orderId,
      productId: item.productId,
      productName: item.productName,
      unitPrice: item.unitPrice,
      quantity: item.quantity,
      subtotal: item.subtotal,
      specialInstructions: item.specialInstructions,
      customizations: item.customizations,
      modifiers: item.modifiers.isNotEmpty
          ? item.modifiers.map((m) => OrderItemModifierModel.fromEntity(m)).toList()
          : null,
      createdAt: item.createdAt.toIso8601String(),
      updatedAt: item.updatedAt.toIso8601String(),
    );
  }

  /// Deserialización desde JSON.
  ///
  /// Hand-written instead of relying on the generated `_$OrderItemModelFromJson`
  /// because the backend wire format differs from the model in three ways:
  ///   1. Numeric columns come as strings (e.g. "20000.00") from PG decimals.
  ///   2. The product name is nested under `product.name`, not a flat field.
  ///   3. order_id / created_at / updated_at can be null on freshly created
  ///      items returned in a POST /orders response.
  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    final product = json['product'] as Map<String, dynamic>?;
    final productName =
        (json['product_name'] as String?) ?? product?['name'] as String? ?? '';

    final modifiersJson = json['modifiers'] as List<dynamic>?;

    return OrderItemModel(
      id: json['id'] as String,
      orderId: (json['order_id'] as String?) ?? '',
      productId: json['product_id'] as String,
      productName: productName,
      unitPrice: parseNum(json['unit_price']),
      quantity: (json['quantity'] as num).toInt(),
      subtotal: parseNum(json['subtotal']),
      specialInstructions: json['special_instructions'] as String?,
      customizations: json['customizations'] as Map<String, dynamic>?,
      modifiers: modifiersJson
          ?.map((m) => OrderItemModifierModel.fromJson(m as Map<String, dynamic>))
          .toList(),
      createdAt: (json['created_at'] as String?) ?? DateTime.now().toIso8601String(),
      updatedAt: (json['updated_at'] as String?) ?? DateTime.now().toIso8601String(),
    );
  }

  /// Serialización a JSON
  Map<String, dynamic> toJson() => _$OrderItemModelToJson(this);
}
