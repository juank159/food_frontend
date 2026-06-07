import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/payment.dart';
import '../repositories/payment_repository.dart';

/// Refund Payment Use Case
/// Reembolsa un pago
class RefundPaymentUseCase {
  final PaymentRepository repository;

  RefundPaymentUseCase(this.repository);

  Future<Either<Failure, Payment>> call({
    required String paymentId,
    double? refundAmount,
    required String refundReason,
  }) async {
    return await repository.refundPayment(
      paymentId: paymentId,
      refundAmount: refundAmount,
      refundReason: refundReason,
    );
  }
}
