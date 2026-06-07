import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/category.dart';
import '../repositories/category_repository.dart';

/// Get Category Tree Use Case
/// Obtiene el árbol de categorías (estructura jerárquica)
class GetCategoryTreeUseCase {
  final CategoryRepository repository;

  GetCategoryTreeUseCase(this.repository);

  Future<Either<Failure, List<Category>>> call({
    bool? isActive,
  }) async {
    return await repository.getCategoryTree(isActive: isActive);
  }
}
