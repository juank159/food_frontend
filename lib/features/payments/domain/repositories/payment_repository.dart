import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/error/failures.dart';
import '../entities/payment.dart';

/// Payment Repository
/// Contrato de repositorio para pagos
abstract class PaymentRepository {
  /// Crea un nuevo pago
  Future<Either<Failure, Payment>> createPayment({
    required String orderId,
    required PaymentMethod paymentMethod,
    required double amount,
    double? receivedAmount,
    String? transactionReference,
    String? notes,
    String? tenantPaymentAccountId,
  });

  /// Procesa el pago completo de una orden
  Future<Either<Failure, Payment>> processOrderPayment({
    required String orderId,
    required PaymentMethod paymentMethod,
    double? receivedAmount,
    String? transactionReference,
    String? notes,
    String? tenantPaymentAccountId,
  });

  /// Procesa pagos divididos
  Future<Either<Failure, List<Payment>>> processSplitPayment({
    required String orderId,
    required List<Map<String, dynamic>> payments,
  });

  /// Cobra una cuenta abierta entera (consolidado FIFO entre tickets).
  Future<Either<Failure, List<Payment>>> processTabPayment({
    required String tabSessionId,
    required double amount,
    required PaymentMethod paymentMethod,
    String? tenantPaymentAccountId,
    double? receivedAmount,
    String? transactionReference,
    String? notes,
  });

  /// Reembolsa un pago
  Future<Either<Failure, Payment>> refundPayment({
    required String paymentId,
    double? refundAmount,
    required String refundReason,
  });

  /// Obtiene todos los pagos con filtros
  Future<Either<Failure, Map<String, dynamic>>> getPayments({
    String? orderId,
    PaymentMethod? paymentMethod,
    PaymentStatus? status,
    String? processedBy,
    int? page,
    int? limit,
  });

  /// Obtiene un pago por ID
  Future<Either<Failure, Payment>> getPaymentById(String id);

  /// Obtiene todos los pagos de una orden
  Future<Either<Failure, List<Payment>>> getPaymentsByOrder(String orderId);
}
