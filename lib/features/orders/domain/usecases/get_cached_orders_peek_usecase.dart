import '../entities/order.dart';
import '../repositories/order_repository.dart';

/// Lista de órdenes cacheada al instante, sin tocar la red — ver
/// `GetCachedProductsPeekUseCase` (mismo patrón, mismo porqué). No
/// está scopeada a ningún rango de fechas: el caller filtra en
/// memoria lo que necesite (ver `OrdersController.loadOrders`).
class GetCachedOrdersPeekUseCase {
  final OrderRepository repository;

  GetCachedOrdersPeekUseCase(this.repository);

  Future<List<Order>?> call() => repository.getCachedOrdersPeek();
}
