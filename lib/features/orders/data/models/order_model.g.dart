// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$OrderModelToJson(OrderModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'order_number': instance.orderNumber,
      'order_type': instance.orderType,
      'order_source': instance.orderSource,
      'status': instance.status,
      'table_id': instance.tableId,
      'table_element_id': instance.tableElementId,
      'table_name': instance.tableName,
      'tab_session_id': instance.tabSessionId,
      'customer_id': instance.customerId,
      'customer_name': instance.customerName,
      'customer_phone': instance.customerPhone,
      'customer_email': instance.customerEmail,
      'delivery_address': instance.deliveryAddress,
      'assigned_to': instance.assignedTo,
      'assigned_to_name': instance.assignedToName,
      'items': instance.items.map((e) => e.toJson()).toList(),
      'subtotal': instance.subtotal,
      'discount_amount': instance.discountAmount,
      'discount_percentage': instance.discountPercentage,
      'delivery_fee': instance.deliveryFee,
      'tip_amount': instance.tipAmount,
      'tax_amount': instance.taxAmount,
      'total_amount': instance.totalAmount,
      'payment_method': instance.paymentMethod,
      'payment_status': instance.paymentStatus,
      'paid_amount': instance.paidAmount,
      'special_instructions': instance.specialInstructions,
      'estimated_time': instance.estimatedTime,
      'confirmed_at': instance.confirmedAt,
      'prepared_at': instance.preparedAt,
      'delivered_at': instance.deliveredAt,
      'completed_at': instance.completedAt,
      'cancelled_at': instance.cancelledAt,
      'metadata': instance.metadata,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };
