import 'package:json_annotation/json_annotation.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../domain/entities/payment.dart';
import '../../../../core/utils/json_parsers.dart';

part 'payment_model.g.dart';

/// Payment Model
/// Modelo de datos para serialización JSON de pagos
@JsonSerializable(explicitToJson: true)
class PaymentModel {
  final String id;
  @JsonKey(name: 'order_id')
  final String orderId;
  @JsonKey(name: 'payment_method')
  final String paymentMethod;
  @JsonKey(fromJson: JsonParsers.parseDouble)
  final double amount;
  @JsonKey(name: 'received_amount', fromJson: JsonParsers.parseNullableDouble)
  final double? receivedAmount;
  @JsonKey(name: 'change_amount', fromJson: JsonParsers.parseNullableDouble)
  final double? changeAmount;
  @JsonKey(name: 'transaction_reference')
  final String? transactionReference;
  final String status;
  @JsonKey(name: 'processed_by')
  final String processedBy;
  @JsonKey(name: 'processed_by_name')
  final String? processedByName;
  @JsonKey(name: 'processed_at')
  final String? processedAt;
  final String? notes;
  @JsonKey(name: 'refunded_by')
  final String? refundedBy;
  @JsonKey(name: 'refunded_by_name')
  final String? refundedByName;
  @JsonKey(name: 'refunded_at')
  final String? refundedAt;
  @JsonKey(name: 'refund_reason')
  final String? refundReason;
  @JsonKey(name: 'tenant_payment_account_id')
  final String? tenantPaymentAccountId;
  // El backend devuelve la cuenta como objeto anidado bajo
  // `tenant_payment_account`. Lo aplanamos en fromJson manualmente para
  // que el modelo siga siendo plano (solo necesitamos el nombre en UI).
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? tenantPaymentAccountName;
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'updated_at')
  final String updatedAt;

  const PaymentModel({
    required this.id,
    required this.orderId,
    required this.paymentMethod,
    required this.amount,
    this.receivedAmount,
    this.changeAmount,
    this.transactionReference,
    required this.status,
    required this.processedBy,
    this.processedByName,
    this.processedAt,
    this.notes,
    this.refundedBy,
    this.refundedByName,
    this.refundedAt,
    this.refundReason,
    this.tenantPaymentAccountId,
    this.tenantPaymentAccountName,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convierte el modelo a entidad de dominio
  Payment toEntity() {
    return Payment(
      id: id,
      orderId: orderId,
      paymentMethod: PaymentMethod.fromString(paymentMethod),
      amount: amount,
      receivedAmount: receivedAmount,
      changeAmount: changeAmount,
      transactionReference: transactionReference,
      status: PaymentStatus.fromString(status),
      processedBy: processedBy,
      processedByName: processedByName,
      processedAt: processedAt != null ? DateTime.parse(processedAt!) : null,
      notes: notes,
      refundedBy: refundedBy,
      refundedByName: refundedByName,
      refundedAt: refundedAt != null ? DateTime.parse(refundedAt!) : null,
      refundReason: refundReason,
      tenantPaymentAccountId: tenantPaymentAccountId,
      tenantPaymentAccountName: tenantPaymentAccountName,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }

  /// Crea un modelo desde una entidad de dominio
  factory PaymentModel.fromEntity(Payment payment) {
    return PaymentModel(
      id: payment.id,
      orderId: payment.orderId,
      paymentMethod: payment.paymentMethod.value,
      amount: payment.amount,
      receivedAmount: payment.receivedAmount,
      changeAmount: payment.changeAmount,
      transactionReference: payment.transactionReference,
      status: payment.status.value,
      processedBy: payment.processedBy,
      processedByName: payment.processedByName,
      processedAt: payment.processedAt?.toIso8601String(),
      notes: payment.notes,
      refundedBy: payment.refundedBy,
      refundedByName: payment.refundedByName,
      refundedAt: payment.refundedAt?.toIso8601String(),
      refundReason: payment.refundReason,
      tenantPaymentAccountId: payment.tenantPaymentAccountId,
      tenantPaymentAccountName: payment.tenantPaymentAccountName,
      createdAt: payment.createdAt.toIso8601String(),
      updatedAt: payment.updatedAt.toIso8601String(),
    );
  }

  /// Deserialización desde JSON. Hacemos el wrapping manual para aplanar
  /// el objeto `tenant_payment_account` anidado que devuelve el backend
  /// en una sola propiedad `tenant_payment_account_name`.
  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    final base = _$PaymentModelFromJson(json);
    final account = json['tenant_payment_account'];
    final accountName = account is Map<String, dynamic>
        ? account['name'] as String?
        : null;
    return PaymentModel(
      id: base.id,
      orderId: base.orderId,
      paymentMethod: base.paymentMethod,
      amount: base.amount,
      receivedAmount: base.receivedAmount,
      changeAmount: base.changeAmount,
      transactionReference: base.transactionReference,
      status: base.status,
      processedBy: base.processedBy,
      processedByName: base.processedByName,
      processedAt: base.processedAt,
      notes: base.notes,
      refundedBy: base.refundedBy,
      refundedByName: base.refundedByName,
      refundedAt: base.refundedAt,
      refundReason: base.refundReason,
      tenantPaymentAccountId: base.tenantPaymentAccountId,
      tenantPaymentAccountName: accountName,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
    );
  }

  /// Serialización a JSON
  Map<String, dynamic> toJson() => _$PaymentModelToJson(this);
}
