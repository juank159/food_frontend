import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/error/failures.dart';
import '../entities/tenant_payment_account.dart';

abstract class TenantPaymentAccountRepository {
  Future<Either<Failure, List<TenantPaymentAccount>>> getAll({
    PaymentMethod? category,
    bool? onlyActive,
  });

  Future<Either<Failure, TenantPaymentAccount>> getById(String id);

  Future<Either<Failure, TenantPaymentAccount>> create({
    required String name,
    required PaymentMethod category,
    String? accountNumber,
    String? accountHolder,
    String? icon,
    String? notes,
    bool? isActive,
    int? sortOrder,
  });

  Future<Either<Failure, TenantPaymentAccount>> update({
    required String id,
    String? name,
    PaymentMethod? category,
    String? accountNumber,
    String? accountHolder,
    String? icon,
    String? notes,
    bool? isActive,
    int? sortOrder,
  });

  Future<Either<Failure, TenantPaymentAccount>> toggleActive(String id);

  Future<Either<Failure, void>> delete(String id);
}
