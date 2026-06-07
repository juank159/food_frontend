import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/error/failures.dart';
import '../entities/payment.dart';
import '../repositories/payment_repository.dart';

/// Use case: cobrar una cuenta abierta entera con un único método +
/// cuenta. El backend distribuye FIFO entre los tickets pendientes y
/// devuelve los payments creados (uno por ticket).
class ProcessTabPaymentUseCase {
  final PaymentRepository repository;

  ProcessTabPaymentUseCase(this.repository);

  Future<Either<Failure, List<Payment>>> call({
    required String tabSessionId,
    required double amount,
    required PaymentMethod paymentMethod,
    String? tenantPaymentAccountId,
    double? receivedAmount,
    String? transactionReference,
    String? notes,
  }) {
    return repository.processTabPayment(
      tabSessionId: tabSessionId,
      amount: amount,
      paymentMethod: paymentMethod,
      tenantPaymentAccountId: tenantPaymentAccountId,
      receivedAmount: receivedAmount,
      transactionReference: transactionReference,
      notes: notes,
    );
  }
}
