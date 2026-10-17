import 'package:dartz/dartz.dart' hide Order;
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_plat/core/config/constants/order_enums.dart';
import 'package:menu_plat/core/error/failures.dart';
import 'package:menu_plat/features/orders/domain/entities/order.dart';
import 'package:menu_plat/features/orders/domain/repositories/order_repository.dart';
import 'package:menu_plat/features/orders/domain/usecases/create_order_usecase.dart';
import 'package:menu_plat/features/orders/domain/usecases/get_active_orders_usecase.dart';
import 'package:menu_plat/features/orders/domain/usecases/get_cached_orders_peek_usecase.dart';
import 'package:menu_plat/features/orders/domain/usecases/get_order_by_id_usecase.dart';
import 'package:menu_plat/features/orders/domain/usecases/get_orders_usecase.dart';
import 'package:menu_plat/features/orders/domain/usecases/update_order_status_usecase.dart';
import 'package:menu_plat/features/orders/presentation/controllers/orders_controller.dart';

Order _order(String id, {required DateTime createdAt}) => Order(
      id: id,
      orderNumber: 'ORD-$id',
      orderType: OrderType.dineIn,
      orderSource: OrderSource.pos,
      status: OrderStatus.pending,
      items: const [],
      subtotal: 10000,
      discountAmount: 0,
      deliveryFee: 0,
      tipAmount: 0,
      taxAmount: 0,
      totalAmount: 10000,
      paymentStatus: PaymentStatus.pending,
      paidAmount: 0,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

class _UnusedRepo implements OrderRepository {
  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeGetOrders implements GetOrdersUseCase {
  Either<Failure, List<Order>> result = const Right(<Order>[]);
  Duration delay = Duration.zero;

  @override
  OrderRepository get repository => _UnusedRepo();

  @override
  Future<Either<Failure, List<Order>>> call({
    OrderStatus? status,
    OrderType? orderType,
    String? tableId,
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    int? page,
    int? limit,
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return result;
  }
}

class _FakeGetCachedPeek implements GetCachedOrdersPeekUseCase {
  List<Order>? result;

  @override
  OrderRepository get repository => _UnusedRepo();

  @override
  Future<List<Order>?> call() async => result;
}

void main() {
  late _FakeGetOrders getOrders;
  late _FakeGetCachedPeek getCachedPeek;
  late OrdersController controller;
  final today = DateTime(2026, 6, 15, 12);
  final yesterday = DateTime(2026, 6, 14, 12);
  final todayStart = DateTime(2026, 6, 15);
  final todayEnd = DateTime(2026, 6, 15, 23, 59, 59);

  setUp(() {
    getOrders = _FakeGetOrders();
    getCachedPeek = _FakeGetCachedPeek();
    controller = OrdersController(
      getOrdersUseCase: getOrders,
      getOrderByIdUseCase: GetOrderByIdUseCase(_UnusedRepo()),
      getActiveOrdersUseCase: GetActiveOrdersUseCase(_UnusedRepo()),
      createOrderUseCase: CreateOrderUseCase(_UnusedRepo()),
      updateOrderStatusUseCase: UpdateOrderStatusUseCase(_UnusedRepo()),
      getCachedOrdersPeekUseCase: getCachedPeek,
    );
  });

  test(
    'local-first: pinta el caché filtrado al rango de fechas efectivo, antes de la red',
    () async {
      getCachedPeek.result = [
        _order('today-1', createdAt: today),
        _order('yesterday-1', createdAt: yesterday),
      ];
      getOrders.result = Right([_order('fresh-1', createdAt: today)]);
      getOrders.delay = const Duration(milliseconds: 20);

      final future = controller.loadOrders(start: todayStart, end: todayEnd);
      await Future<void>.delayed(const Duration(milliseconds: 5));

      // El pintado instantáneo solo debe incluir la orden de HOY — la
      // de ayer queda afuera aunque esté en la misma caché cruda.
      expect(controller.orders.map((o) => o.id), ['today-1']);
      expect(controller.isLoading.value, isFalse);

      await future;
      expect(controller.orders.map((o) => o.id), ['fresh-1']);
    },
  );

  test(
    'si el peek no tiene NINGUNA orden del rango efectivo, no pinta nada (muestra loading)',
    () async {
      getCachedPeek.result = [_order('yesterday-1', createdAt: yesterday)];
      getOrders.result = Right([_order('fresh-1', createdAt: today)]);

      await controller.loadOrders(start: todayStart, end: todayEnd);

      expect(controller.orders.map((o) => o.id), ['fresh-1']);
    },
  );

  test('con filtro de estado explícito: no usa el peek de caché', () async {
    getCachedPeek.result = [_order('cached-1', createdAt: today)];
    getOrders.result = Right([_order('fresh-1', createdAt: today)]);

    await controller.loadOrders(status: OrderStatus.ready);

    expect(controller.orders.map((o) => o.id), ['fresh-1']);
  });

  test(
    'si ya pintó del caché y la red falla, no borra lo pintado ni muestra error',
    () async {
      getCachedPeek.result = [_order('today-1', createdAt: today)];
      getOrders.result = const Left(NetworkFailure());

      await controller.loadOrders(start: todayStart, end: todayEnd);

      expect(controller.orders.map((o) => o.id), ['today-1']);
      expect(controller.errorMessage.value, isEmpty);
    },
  );
}
