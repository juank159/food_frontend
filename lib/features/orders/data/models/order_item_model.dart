import 'package:json_annotation/json_annotation.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/utils/json_parsers.dart';
import '../../domain/entities/order_item.dart';
import 'order_item_modifier_model.dart';

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
  /// `true` si el producto requiere paso por cocina/barra. Se lee del
  /// JSON anidado `product.requires_preparation`. Default `true` por
  /// compatibilidad con responses viejos: los items siguen yendo a
  /// cocina hasta que se actualice el producto al nuevo flag.
  @JsonKey(name: 'requires_preparation')
  final bool requiresPreparation;
  /// Categoría del producto — usada para agrupar la comanda de cocina e
  /// imprimir tickets separados por categoría. Se leen del JSON anidado
  /// `product.category`. No se serializan de vuelta (no van en el create).
  @JsonKey(includeToJson: false)
  final String? categoryId;
  @JsonKey(includeToJson: false)
  final String? categoryName;
  /// Si la categoría imprime comanda de cocina. Default `true`.
  @JsonKey(includeToJson: false)
  final bool categoryPrintsKitchen;
  /// Estado individual del item (pending/preparing/ready/delivered).
  final String? status;
  @JsonKey(name: 'prepared_at')
  final String? preparedAt;
  @JsonKey(name: 'delivered_at')
  final String? deliveredAt;
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
    this.requiresPreparation = true,
    this.categoryId,
    this.categoryName,
    this.categoryPrintsKitchen = true,
    this.status,
    this.preparedAt,
    this.deliveredAt,
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
      status: status != null
          ? OrderStatus.fromString(status!)
          : OrderStatus.pending,
      requiresPreparation: requiresPreparation,
      preparedAt:
          preparedAt != null ? DateTime.parse(preparedAt!) : null,
      deliveredAt:
          deliveredAt != null ? DateTime.parse(deliveredAt!) : null,
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

    // `requires_preparation` puede venir en dos lugares:
    //   - plano en el item (cuando el backend desnormaliza el flag al
    //     crear la orden — útil para snapshot histórico).
    //   - dentro de `product.requires_preparation` cuando el backend
    //     trae el JOIN del producto.
    // Default `true` si no viene en ningún lado (orden vieja pre-migración).
    final requiresPreparation = (json['requires_preparation'] as bool?) ??
        (product?['requires_preparation'] as bool?) ??
        true;

    // Categoría del producto (para agrupar la comanda por categoría).
    final category = product?['category'] as Map<String, dynamic>?;

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
      requiresPreparation: requiresPreparation,
      categoryId: category?['id'] as String?,
      categoryName: category?['name'] as String?,
      categoryPrintsKitchen:
          (category?['prints_kitchen'] as bool?) ?? true,
      status: json['status'] as String?,
      preparedAt: json['prepared_at'] as String?,
      deliveredAt: json['delivered_at'] as String?,
      createdAt: (json['created_at'] as String?) ?? DateTime.now().toIso8601String(),
      updatedAt: (json['updated_at'] as String?) ?? DateTime.now().toIso8601String(),
    );
  }

  /// Serialización a JSON
  Map<String, dynamic> toJson() => _$OrderItemModelToJson(this);
}
