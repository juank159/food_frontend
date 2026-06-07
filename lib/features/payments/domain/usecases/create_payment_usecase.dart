import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/error/failures.dart';
import '../entities/payment.dart';
import '../repositories/payment_repository.dart';

/// Crea un payment individual (pago parcial o total) en la orden.
///
/// **Caso de uso clave:** cobros parciales. El cajero recibe $2.000 en
/// efectivo de una cuenta de $7.000 — ese dinero YA está en su mano y
/// debe quedar registrado al instante en backend (caja + payments).
///
/// A diferencia de `processSplitPayment` (batch atómico de N pagos en
/// una transacción), este use case registra UN pago independiente que
/// queda persistido aunque el operario cierre el flujo. El siguiente
/// pago se hace en otra request — el backend valida en cada uno que
/// `sum(payments) <= total`.
class CreatePaymentUseCase {
  final PaymentRepository repository;

  CreatePaymentUseCase(this.repository);

  Future<Either<Failure, Payment>> call({
    required String orderId,
    required PaymentMethod paymentMethod,
    required double amount,
    double? receivedAmount,
    String? transactionReference,
    String? notes,
    String? tenantPaymentAccountId,
  }) {
    return repository.createPayment(
      orderId: orderId,
      paymentMethod: paymentMethod,
      amount: amount,
      receivedAmount: receivedAmount,
      transactionReference: transactionReference,
      notes: notes,
      tenantPaymentAccountId: tenantPaymentAccountId,
    );
  }
}
