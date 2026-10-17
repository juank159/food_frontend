import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_plat/core/error/failures.dart';
import 'package:menu_plat/features/customers/domain/entities/customer.dart';
import 'package:menu_plat/features/customers/domain/entities/customer_statistics.dart';
import 'package:menu_plat/features/customers/domain/repositories/customer_repository.dart';
import 'package:menu_plat/features/customers/domain/usecases/delete_customer_usecase.dart';
import 'package:menu_plat/features/customers/domain/usecases/get_cached_customers_peek_usecase.dart';
import 'package:menu_plat/features/customers/domain/usecases/get_customer_statistics_usecase.dart';
import 'package:menu_plat/features/customers/domain/usecases/get_customers_usecase.dart';
import 'package:menu_plat/features/customers/presentation/controllers/customers_controller.dart';

Customer _customer(String id, {bool isActive = true}) => Customer(
      id: id,
      fullName: 'Cliente $id',
      phone: '3000000000',
      isActive: isActive,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

class _UnusedRepo implements CustomerRepository {
  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeGetCustomers implements GetCustomersUseCase {
  Either<Failure, List<Customer>> result = Right(<Customer>[]);
  Duration delay = Duration.zero;

  @override
  CustomerRepository get repository => _UnusedRepo();

  @override
  Future<Either<Failure, List<Customer>>> call({
    bool? isActive,
    String? search,
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return result;
  }
}

class _FakeGetCachedPeek implements GetCachedCustomersPeekUseCase {
  List<Customer>? result;

  @override
  CustomerRepository get repository => _UnusedRepo();

  @override
  Future<List<Customer>?> call() async => result;
}

class _FakeGetStatistics implements GetCustomerStatisticsUseCase {
  @override
  CustomerRepository get repository => _UnusedRepo();

  @override
  Future<Either<Failure, CustomerStatistics>> call() async =>
      Right(CustomerStatistics.empty());
}

void main() {
  late _FakeGetCustomers getCustomers;
  late _FakeGetCachedPeek getCachedPeek;
  late CustomersController controller;

  setUp(() {
    getCustomers = _FakeGetCustomers();
    getCachedPeek = _FakeGetCachedPeek();
    controller = CustomersController(
      getCustomersUseCase: getCustomers,
      getStatisticsUseCase: _FakeGetStatistics(),
      deleteCustomerUseCase: DeleteCustomerUseCase(_UnusedRepo()),
      getCachedCustomersPeekUseCase: getCachedPeek,
    );
  });

  test(
    'local-first: pinta el caché de inmediato (sin búsqueda, default al abrir)',
    () async {
      getCachedPeek.result = [_customer('cached-1')];
      getCustomers.result = Right([_customer('fresh-1')]);
      getCustomers.delay = const Duration(milliseconds: 20);

      final future = controller.loadCustomers();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(controller.customers.map((c) => c.id), ['cached-1']);
      expect(controller.isLoading.value, isFalse);

      await future;
      expect(controller.customers.map((c) => c.id), ['fresh-1']);
    },
  );

  test('sin caché: muestra loading hasta que responda la red', () async {
    getCachedPeek.result = null;
    getCustomers.result = Right([_customer('fresh-1')]);

    await controller.loadCustomers();

    expect(controller.customers.map((c) => c.id), ['fresh-1']);
  });

  test(
    '"Solo activos": filtra el peek en memoria antes de la red',
    () async {
      getCachedPeek.result = [
        _customer('activo-1', isActive: true),
        _customer('inactivo-1', isActive: false),
      ];
      getCustomers.result = Right([_customer('fresh-1')]);
      getCustomers.delay = const Duration(milliseconds: 20);

      controller.showOnlyActive.value = true;
      final future = controller.loadCustomers();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(controller.customers.map((c) => c.id), ['activo-1']);
      await future;
    },
  );

  test(
    'si ya pintó del caché y la red falla, no borra lo pintado ni muestra error',
    () async {
      getCachedPeek.result = [_customer('cached-1')];
      getCustomers.result = const Left(NetworkFailure());

      await controller.loadCustomers();

      expect(controller.customers.map((c) => c.id), ['cached-1']);
      expect(controller.errorMessage.value, isEmpty);
    },
  );
}
