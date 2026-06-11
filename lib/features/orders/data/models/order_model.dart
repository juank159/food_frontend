import 'package:json_annotation/json_annotation.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../domain/entities/order.dart';
import 'order_item_model.dart';
import '../../../../core/utils/json_parsers.dart';

part 'order_model.g.dart';

/// Order Model
/// Modelo de datos para serialización JSON de órdenes
@JsonSerializable(explicitToJson: true, createFactory: false)
class OrderModel {
  final String id;
  @JsonKey(name: 'order_number')
  final String orderNumber;
  @JsonKey(name: 'order_type')
  final String orderType;
  @JsonKey(name: 'order_source')
  final String orderSource;
  final String status;
  @JsonKey(name: 'table_id')
  final String? tableId;
  @JsonKey(name: 'table_element_id')
  final String? tableElementId;
  @JsonKey(name: 'table_name')
  final String? tableName;
  /// Label legible snapshot al crear la orden ("Mesa 1 · Areas verdes").
  /// **Siempre preferir este campo** para mostrar al usuario — el
  /// `tableElementId` es un UUID interno ilegible. Si por algún motivo
  /// está vacío (ordenes viejas pre-migración), caer a `tableName`,
  /// y solo como último recurso a `tableElementId`.
  @JsonKey(name: 'table_label')
  final String? tableLabel;
  @JsonKey(name: 'tab_session_id')
  final String? tabSessionId;
  @JsonKey(name: 'customer_id')
  final String? customerId;
  @JsonKey(name: 'customer_name')
  final String? customerName;
  @JsonKey(name: 'customer_phone')
  final String? customerPhone;
  @JsonKey(name: 'customer_email')
  final String? customerEmail;
  @JsonKey(name: 'delivery_address')
  final Map<String, dynamic>? deliveryAddress;
  @JsonKey(name: 'assigned_to')
  final String? assignedTo;
  @JsonKey(name: 'assigned_to_name')
  final String? assignedToName;
  final List<OrderItemModel> items;
  @JsonKey(fromJson: JsonParsers.parseDouble)
  final double subtotal;
  @JsonKey(name: 'discount_amount', fromJson: JsonParsers.parseDouble)
  final double discountAmount;
  @JsonKey(name: 'discount_percentage', fromJson: JsonParsers.parseNullableDouble)
  final double? discountPercentage;
  @JsonKey(name: 'delivery_fee', fromJson: JsonParsers.parseDouble)
  final double deliveryFee;
  @JsonKey(name: 'tip_amount', fromJson: JsonParsers.parseDouble)
  final double tipAmount;
  @JsonKey(name: 'tax_amount', fromJson: JsonParsers.parseDouble)
  final double taxAmount;
  @JsonKey(name: 'total_amount', fromJson: JsonParsers.parseDouble)
  final double totalAmount;
  @JsonKey(name: 'payment_method')
  final String? paymentMethod;
  @JsonKey(name: 'payment_status')
  final String paymentStatus;
  /// Suma de pagos `completed` asociados a la orden. Derivado de
  /// `payments[]` del JSON del backend en `fromJson`. NO viaja como
  /// columna propia — el server no la persiste; la calculamos cada vez
  /// para que la UI sepa cuánto se ha cobrado sin pedir extra requests.
  final double paidAmount;
  @JsonKey(name: 'special_instructions')
  final String? specialInstructions;
  @JsonKey(name: 'estimated_time')
  final int? estimatedTime;
  @JsonKey(name: 'confirmed_at')
  final String? confirmedAt;
  @JsonKey(name: 'prepared_at')
  final String? preparedAt;
  @JsonKey(name: 'delivered_at')
  final String? deliveredAt;
  @JsonKey(name: 'completed_at')
  final String? completedAt;
  @JsonKey(name: 'cancelled_at')
  final String? cancelledAt;
  final Map<String, dynamic>? metadata;
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'updated_at')
  final String updatedAt;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.orderType,
    required this.orderSource,
    required this.status,
    this.tableId,
    this.tableElementId,
    this.tableName,
    this.tableLabel,
    this.tabSessionId,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.deliveryAddress,
    this.assignedTo,
    this.assignedToName,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    this.discountPercentage,
    required this.deliveryFee,
    required this.tipAmount,
    required this.taxAmount,
    required this.totalAmount,
    this.paymentMethod,
    required this.paymentStatus,
    this.paidAmount = 0,
    this.specialInstructions,
    this.estimatedTime,
    this.confirmedAt,
    this.preparedAt,
    this.deliveredAt,
    this.completedAt,
    this.cancelledAt,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convierte el modelo a entidad de dominio
  Order toEntity() {
    return Order(
      id: id,
      orderNumber: orderNumber,
      orderType: OrderType.fromString(orderType),
      orderSource: OrderSource.fromString(orderSource),
      status: OrderStatus.fromString(status),
      tableId: tableId,
      tableElementId: tableElementId,
      tableName: tableName,
      tableLabel: tableLabel,
      tabSessionId: tabSessionId,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      deliveryAddress: deliveryAddress,
      assignedTo: assignedTo,
      assignedToName: assignedToName,
      items: items.map((item) => item.toEntity()).toList(),
      subtotal: subtotal,
      discountAmount: discountAmount,
      discountPercentage: discountPercentage,
      deliveryFee: deliveryFee,
      tipAmount: tipAmount,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod != null
          ? PaymentMethod.fromString(paymentMethod!)
          : null,
      paymentStatus: PaymentStatus.fromString(paymentStatus),
      paidAmount: paidAmount,
      specialInstructions: specialInstructions,
      estimatedTime: estimatedTime,
      confirmedAt:
          confirmedAt != null ? DateTime.parse(confirmedAt!) : null,
      preparedAt: preparedAt != null ? DateTime.parse(preparedAt!) : null,
      deliveredAt:
          deliveredAt != null ? DateTime.parse(deliveredAt!) : null,
      completedAt:
          completedAt != null ? DateTime.parse(completedAt!) : null,
      cancelledAt:
          cancelledAt != null ? DateTime.parse(cancelledAt!) : null,
      metadata: metadata,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }

  /// Crea un modelo desde una entidad de dominio
  factory OrderModel.fromEntity(Order order) {
    return OrderModel(
      id: order.id,
      orderNumber: order.orderNumber,
      orderType: order.orderType.value,
      orderSource: order.orderSource.value,
      status: order.status.value,
      tableId: order.tableId,
      tableElementId: order.tableElementId,
      tableName: order.tableName,
      tableLabel: order.tableLabel,
      tabSessionId: order.tabSessionId,
      customerId: order.customerId,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      customerEmail: order.customerEmail,
      deliveryAddress: order.deliveryAddress,
      assignedTo: order.assignedTo,
      assignedToName: order.assignedToName,
      items: order.items
          .map((item) => OrderItemModel.fromEntity(item))
          .toList(),
      subtotal: order.subtotal,
      discountAmount: order.discountAmount,
      discountPercentage: order.discountPercentage,
      deliveryFee: order.deliveryFee,
      tipAmount: order.tipAmount,
      taxAmount: order.taxAmount,
      totalAmount: order.totalAmount,
      paymentMethod: order.paymentMethod?.value,
      paymentStatus: order.paymentStatus.value,
      paidAmount: order.paidAmount,
      specialInstructions: order.specialInstructions,
      estimatedTime: order.estimatedTime,
      confirmedAt: order.confirmedAt?.toIso8601String(),
      preparedAt: order.preparedAt?.toIso8601String(),
      deliveredAt: order.deliveredAt?.toIso8601String(),
      completedAt: order.completedAt?.toIso8601String(),
      cancelledAt: order.cancelledAt?.toIso8601String(),
      metadata: order.metadata,
      createdAt: order.createdAt.toIso8601String(),
      updatedAt: order.updatedAt.toIso8601String(),
    );
  }

  /// Deserialización desde JSON.
  ///
  /// Hand-written to tolerate the actual backend wire format:
  ///   - Decimal columns (`subtotal`, `tax_amount`, etc.) come as strings
  ///     from Postgres NUMERIC; the generated factory's `as num` cast crashes.
  ///   - `payment_status`, `payment_method`, `tip_amount`, `discount_percentage`
  ///     are not always present in the response.
  ///   - Nested `table.name`, `assigned_to_user.full_name`, etc. are flattened
  ///     into table_name / assigned_to_name for the UI.
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    double? parseNumOrNull(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    final table = json['table'] as Map<String, dynamic>?;
    final assignedToUser = json['assigned_to_user'] as Map<String, dynamic>?;
    final itemsJson = (json['items'] as List<dynamic>?) ?? const [];

    // Derivamos paid_amount sumando los payments completed del JSON
    // anidado. El backend NO lo expone como columna, así que cada
    // request lo calculamos del lado cliente. Esto da el progreso de
    // pago visible en la card aunque el `payment_status` siga "pending".
    final paymentsJson = (json['payments'] as List<dynamic>?) ?? const [];
    double paid = 0;
    for (final p in paymentsJson) {
      if (p is! Map<String, dynamic>) continue;
      final status = p['status']?.toString() ?? '';
      if (status != 'completed') continue;
      paid += parseNum(p['amount']);
    }

    return OrderModel(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String,
      orderType: json['order_type'] as String,
      orderSource: json['order_source'] as String,
      status: json['status'] as String,
      tableId: json['table_id'] as String?,
      tableElementId: json['table_element_id'] as String?,
      tableName: (json['table_name'] as String?) ?? table?['name'] as String?,
      tableLabel: json['table_label'] as String?,
      tabSessionId: json['tab_session_id'] as String?,
      customerId: json['customer_id'] as String?,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      customerEmail: json['customer_email'] as String?,
      deliveryAddress: json['delivery_address'] as Map<String, dynamic>?,
      assignedTo: json['assigned_to'] as String?,
      assignedToName: (json['assigned_to_name'] as String?) ??
          assignedToUser?['full_name'] as String?,
      items: itemsJson
          .map((i) => OrderItemModel.fromJson(i as Map<String, dynamic>))
          .toList(),
      subtotal: parseNum(json['subtotal']),
      discountAmount: parseNum(json['discount_amount']),
      discountPercentage: parseNumOrNull(json['discount_percentage']),
      deliveryFee: parseNum(json['delivery_fee']),
      tipAmount: parseNum(json['tip_amount']),
      taxAmount: parseNum(json['tax_amount']),
      totalAmount: parseNum(json['total_amount']),
      paymentMethod: json['payment_method'] as String?,
      paymentStatus: (json['payment_status'] as String?) ?? 'pending',
      paidAmount: paid,
      specialInstructions: json['special_instructions'] as String?,
      estimatedTime: (json['estimated_time'] as num?)?.toInt(),
      confirmedAt: json['confirmed_at'] as String?,
      preparedAt: (json['prepared_at'] as String?) ??
          json['preparing_at'] as String?,
      deliveredAt: json['delivered_at'] as String?,
      completedAt: json['completed_at'] as String?,
      cancelledAt: json['cancelled_at'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  /// Serialización a JSON
  Map<String, dynamic> toJson() => _$OrderModelToJson(this);
}
