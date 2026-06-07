// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaymentModel _$PaymentModelFromJson(Map<String, dynamic> json) => PaymentModel(
  id: json['id'] as String,
  orderId: json['order_id'] as String,
  paymentMethod: json['payment_method'] as String,
  amount: JsonParsers.parseDouble(json['amount']),
  receivedAmount: JsonParsers.parseNullableDouble(json['received_amount']),
  changeAmount: JsonParsers.parseNullableDouble(json['change_amount']),
  transactionReference: json['transaction_reference'] as String?,
  status: json['status'] as String,
  processedBy: json['processed_by'] as String,
  processedByName: json['processed_by_name'] as String?,
  processedAt: json['processed_at'] as String?,
  notes: json['notes'] as String?,
  refundedBy: json['refunded_by'] as String?,
  refundedByName: json['refunded_by_name'] as String?,
  refundedAt: json['refunded_at'] as String?,
  refundReason: json['refund_reason'] as String?,
  tenantPaymentAccountId: json['tenant_payment_account_id'] as String?,
  createdAt: json['created_at'] as String,
  updatedAt: json['updated_at'] as String,
);

Map<String, dynamic> _$PaymentModelToJson(PaymentModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'order_id': instance.orderId,
      'payment_method': instance.paymentMethod,
      'amount': instance.amount,
      'received_amount': instance.receivedAmount,
      'change_amount': instance.changeAmount,
      'transaction_reference': instance.transactionReference,
      'status': instance.status,
      'processed_by': instance.processedBy,
      'processed_by_name': instance.processedByName,
      'processed_at': instance.processedAt,
      'notes': instance.notes,
      'refunded_by': instance.refundedBy,
      'refunded_by_name': instance.refundedByName,
      'refunded_at': instance.refundedAt,
      'refund_reason': instance.refundReason,
      'tenant_payment_account_id': instance.tenantPaymentAccountId,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };
