import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_plat/core/error/failures.dart';
import 'package:menu_plat/features/products/domain/entities/product.dart';
import 'package:menu_plat/features/products/domain/usecases/get_available_products_usecase.dart';
import 'package:menu_plat/features/products/domain/usecases/get_cached_products_peek_usecase.dart';
import 'package:menu_plat/features/products/domain/usecases/get_product_by_id_usecase.dart';
import 'package:menu_plat/features/products/domain/usecases/get_products_usecase.dart';
import 'package:menu_plat/features/products/domain/repositories/product_repository.dart';
import 'package:menu_plat/features/products/presentation/controllers/products_controller.dart';

Product _product(String id) => Product(
      id: id,
      name: 'Producto $id',
      description: '',
      basePrice: 1000,
      preparationTime: 0,
      isAvailable: true,
      tags: const [],
      allergens: const [],
      trackInventory: false,
      totalSold: 0,
      totalRevenue: 0,
      categoryId: 'cat-1',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

/// Fakes de mano (sin mockito) — mismo criterio que el resto del repo
/// de frontend, que no trae librería de mocking.
class _FakeGetProducts implements GetProductsUseCase {
  Either<Failure, List<Product>> result = Right(<Product>[]);
  int calls = 0;

  @override
  ProductRepository get repository => _UnusedRepo();

  /// Simula la demora real de un pedido de red — sin esto, el fake
  /// resuelve en el mismo microtask y no se puede observar el estado
  /// "ya pintado del caché, todavía esperando la red".
  Duration delay = Duration.zero;

  @override
  Future<Either<Failure, List<Product>>> call({
    String? categoryId,
    bool? isAvailable,
    String? search,
    List<String>? tags,
    int? page,
    int? limit,
  }) async {
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return result;
  }
}

class _FakeGetCachedPeek implements GetCachedProductsPeekUseCase {
  List<Product>? result;

  @override
  ProductRepository get repository => _UnusedRepo();

  @override
  Future<List<Product>?> call() async => result;
}

void main() {
  late _FakeGetProducts getProducts;
  late _FakeGetCachedPeek getCachedPeek;
  late ProductsController controller;

  setUp(() {
    getProducts = _FakeGetProducts();
    getCachedPeek = _FakeGetCachedPeek();
    controller = ProductsController(
      getProductsUseCase: getProducts,
      getProductByIdUseCase: GetProductByIdUseCase(_UnusedRepo()),
      getAvailableProductsUseCase: GetAvailableProductsUseCase(_UnusedRepo()),
      getCachedProductsPeekUseCase: getCachedPeek,
    );
  });

  test(
    'local-first: si hay caché, la pinta de inmediato SIN mostrar el loading grande',
    () async {
      getCachedPeek.result = [_product('cached-1')];
      // La red tarda — mientras no resuelva, isLoading debe seguir false
      // porque ya pintamos algo desde la caché.
      getProducts.result = Right([_product('fresh-1')]);
      getProducts.delay = const Duration(milliseconds: 20);

      final future = controller.loadProducts();
      // Antes de que la red resuelva, ya debería estar pintado del caché.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(controller.products.map((p) => p.id), contains('cached-1'));
      expect(controller.isLoading.value, isFalse);

      await future;
      // Al terminar, la lista "real" del servidor reemplaza la del caché.
      expect(controller.products.map((p) => p.id), ['fresh-1']);
    },
  );

  test(
    'sin caché (primera vez): sí muestra el loading grande hasta que responda la red',
    () async {
      getCachedPeek.result = null;
      getProducts.result = Right([_product('fresh-1')]);

      await controller.loadProducts();

      expect(controller.products.map((p) => p.id), ['fresh-1']);
      expect(controller.isLoading.value, isFalse); // ya terminó
    },
  );

  test(
    'BUG a evitar: si ya pintamos desde caché y la red falla, NO pisamos la lista ni mostramos error',
    () async {
      getCachedPeek.result = [_product('cached-1')];
      getProducts.result = const Left(NetworkFailure());

      await controller.loadProducts();

      // Se queda con lo que ya había pintado del caché — no lo vacía.
      expect(controller.products.map((p) => p.id), ['cached-1']);
      expect(controller.errorMessage.value, isEmpty);
    },
  );

  test(
    'con filtros explícitos (ej. búsqueda): NO usa el peek de caché',
    () async {
      getCachedPeek.result = [_product('cached-1')];
      getProducts.result = Right([_product('search-result')]);

      await controller.loadProducts(search: 'pizza');

      expect(controller.products.map((p) => p.id), ['search-result']);
    },
  );
}

/// Nunca se llama de verdad en estos tests (solo satisface el
/// constructor de GetProductByIdUseCase/GetAvailableProductsUseCase,
/// que no se ejercitan acá) — cualquier método real tira.
class _UnusedRepo implements ProductRepository {
  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
