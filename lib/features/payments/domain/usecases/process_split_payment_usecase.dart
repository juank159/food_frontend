import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/payment.dart';
import '../repositories/payment_repository.dart';

/// Process Split Payment Use Case
/// Procesa pagos divididos
class ProcessSplitPaymentUseCase {
  final PaymentRepository repository;

  ProcessSplitPaymentUseCase(this.repository);

  Future<Either<Failure, List<Payment>>> call({
    required String orderId,
    required List<Map<String, dynamic>> payments,
  }) async {
    return await repository.processSplitPayment(
      orderId: orderId,
      payments: payments,
    );
  }
}
