import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/payment.dart';
import '../repositories/payment_repository.dart';

/// Get Payments By Order Use Case
/// Obtiene todos los pagos de una orden
class GetPaymentsByOrderUseCase {
  final PaymentRepository repository;

  GetPaymentsByOrderUseCase(this.repository);

  Future<Either<Failure, List<Payment>>> call(String orderId) async {
    return await repository.getPaymentsByOrder(orderId);
  }
}
