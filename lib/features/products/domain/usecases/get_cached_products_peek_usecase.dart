import '../entities/product.dart';
import '../repositories/product_repository.dart';

/// Catálogo cacheado al instante, sin tocar la red — para pintar la
/// pantalla de productos "local-first" antes de que `GetProductsUseCase`
/// termine de refrescar contra el servidor. `null` si nunca se cacheó
/// nada (primera vez que se abre la app).
class GetCachedProductsPeekUseCase {
  final ProductRepository repository;

  GetCachedProductsPeekUseCase(this.repository);

  Future<List<Product>?> call() => repository.getCachedProductsPeek();
}
