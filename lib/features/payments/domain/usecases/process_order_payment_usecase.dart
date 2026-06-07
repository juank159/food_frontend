import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/error/failures.dart';
import '../entities/payment.dart';
import '../repositories/payment_repository.dart';

/// Process Order Payment Use Case
/// Procesa el pago completo de una orden
class ProcessOrderPaymentUseCase {
  final PaymentRepository repository;

  ProcessOrderPaymentUseCase(this.repository);

  Future<Either<Failure, Payment>> call({
    required String orderId,
    required PaymentMethod paymentMethod,
    double? receivedAmount,
    String? transactionReference,
    String? notes,
    String? tenantPaymentAccountId,
  }) async {
    return await repository.processOrderPayment(
      orderId: orderId,
      paymentMethod: paymentMethod,
      receivedAmount: receivedAmount,
      transactionReference: transactionReference,
      notes: notes,
      tenantPaymentAccountId: tenantPaymentAccountId,
    );
  }
}
