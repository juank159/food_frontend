import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/customer.dart';
import '../entities/customer_address.dart';
import '../entities/customer_statistics.dart';

/// Customer Repository
/// Contrato del dominio para clientes.
abstract class CustomerRepository {
  Future<Either<Failure, List<Customer>>> getCustomers({
    bool? isActive,
    String? search,
  });

  Future<Either<Failure, Customer>> getCustomerById(String id);

  Future<Either<Failure, Customer?>> getCustomerByPhone(String phone);

  Future<Either<Failure, CustomerStatistics>> getStatistics();

  Future<Either<Failure, List<CustomerAddress>>> getAddresses(String customerId);

  Future<Either<Failure, Customer>> createCustomer({
    required String fullName,
    required String phone,
    String? email,
    String? notes,
    bool isActive = true,
  });

  Future<Either<Failure, Customer>> updateCustomer({
    required String id,
    String? fullName,
    String? phone,
    String? email,
    String? notes,
    bool? isActive,
  });

  Future<Either<Failure, void>> deleteCustomer(String id);

  Future<Either<Failure, CustomerAddress>> createAddress({
    required String customerId,
    required String label,
    required String addressLine1,
    String? addressLine2,
    required String city,
    String? state,
    String? postalCode,
    double? latitude,
    double? longitude,
    String? deliveryInstructions,
    bool isDefault = false,
  });

  Future<Either<Failure, CustomerAddress>> updateAddress({
    required String addressId,
    String? label,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? postalCode,
    double? latitude,
    double? longitude,
    String? deliveryInstructions,
    bool? isDefault,
  });

  Future<Either<Failure, void>> deleteAddress(String addressId);
}
