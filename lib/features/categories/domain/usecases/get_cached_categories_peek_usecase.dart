import '../entities/category.dart';
import '../repositories/category_repository.dart';

/// Catálogo de categorías cacheado al instante, sin tocar la red — ver
/// `GetCachedProductsPeekUseCase` (mismo patrón, mismo porqué).
class GetCachedCategoriesPeekUseCase {
  final CategoryRepository repository;

  GetCachedCategoriesPeekUseCase(this.repository);

  Future<List<Category>?> call() => repository.getCachedCategoriesPeek();
}
