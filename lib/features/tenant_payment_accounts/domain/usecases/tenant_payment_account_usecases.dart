import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/error/failures.dart';
import '../entities/tenant_payment_account.dart';
import '../repositories/tenant_payment_account_repository.dart';

/// Bundle de use cases del feature. Lo agrupamos en un solo archivo
/// porque cada método es un thin wrapper sobre el repositorio — un
/// archivo por método agrega ceremonia sin valor.
class TenantPaymentAccountUseCases {
  final TenantPaymentAccountRepository repository;

  TenantPaymentAccountUseCases(this.repository);

  Future<Either<Failure, List<TenantPaymentAccount>>> getAll({
    PaymentMethod? category,
    bool? onlyActive,
  }) {
    return repository.getAll(category: category, onlyActive: onlyActive);
  }

  Future<Either<Failure, TenantPaymentAccount>> getById(String id) =>
      repository.getById(id);

  Future<Either<Failure, TenantPaymentAccount>> create({
    required String name,
    required PaymentMethod category,
    String? accountNumber,
    String? accountHolder,
    String? icon,
    String? notes,
    bool? isActive,
    int? sortOrder,
  }) {
    return repository.create(
      name: name,
      category: category,
      accountNumber: accountNumber,
      accountHolder: accountHolder,
      icon: icon,
      notes: notes,
      isActive: isActive,
      sortOrder: sortOrder,
    );
  }

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
  }) {
    return repository.update(
      id: id,
      name: name,
      category: category,
      accountNumber: accountNumber,
      accountHolder: accountHolder,
      icon: icon,
      notes: notes,
      isActive: isActive,
      sortOrder: sortOrder,
    );
  }

  Future<Either<Failure, TenantPaymentAccount>> toggleActive(String id) =>
      repository.toggleActive(id);

  Future<Either<Failure, void>> delete(String id) => repository.delete(id);
}
