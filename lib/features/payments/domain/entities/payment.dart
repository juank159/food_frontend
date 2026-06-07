import 'package:equatable/equatable.dart';
import '../../../../core/config/constants/order_enums.dart';

/// Payment Entity
/// Entidad de dominio para pagos
class Payment extends Equatable {
  final String id;
  final String orderId;
  final PaymentMethod paymentMethod;
  final double amount;
  final double? receivedAmount;
  final double? changeAmount;
  final String? transactionReference;
  final PaymentStatus status;
  final String processedBy;
  final String? processedByName;
  final DateTime? processedAt;
  final String? notes;
  final String? refundedBy;
  final String? refundedByName;
  final DateTime? refundedAt;
  final String? refundReason;
  // Cuenta concreta del tenant (Nequi, Bancolombia, etc.). Null cuando
  // el pago se procesó solo con la categoría general.
  final String? tenantPaymentAccountId;
  final String? tenantPaymentAccountName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Payment({
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

  /// Verifica si el pago está completado
  bool get isCompleted => status == PaymentStatus.completed;

  /// Verifica si el pago está pendiente
  bool get isPending => status == PaymentStatus.pending;

  /// Verifica si el pago está reembolsado
  bool get isRefunded => status == PaymentStatus.refunded;

  /// Verifica si el pago falló
  bool get isFailed => status == PaymentStatus.failed;

  /// Verifica si el pago fue en efectivo
  bool get isCash => paymentMethod == PaymentMethod.cash;

  /// Verifica si tiene cambio
  bool get hasChange => changeAmount != null && changeAmount! > 0;

  /// Verifica si el pago puede ser reembolsado
  bool get canBeRefunded => isCompleted && !isRefunded;

  @override
  List<Object?> get props => [
        id,
        orderId,
        paymentMethod,
        amount,
        receivedAmount,
        changeAmount,
        transactionReference,
        status,
        processedBy,
        processedByName,
        processedAt,
        notes,
        refundedBy,
        refundedByName,
        refundedAt,
        refundReason,
        tenantPaymentAccountId,
        tenantPaymentAccountName,
        createdAt,
        updatedAt,
      ];
}
