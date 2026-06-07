import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/category.dart';
import '../repositories/category_repository.dart';

/// Get Categories Use Case
/// Obtiene todas las categorías con filtros opcionales
class GetCategoriesUseCase {
  final CategoryRepository repository;

  GetCategoriesUseCase(this.repository);

  Future<Either<Failure, List<Category>>> call({
    bool? isActive,
    String? search,
    int? page,
    int? limit,
  }) async {
    return await repository.getCategories(
      isActive: isActive,
      search: search,
      page: page,
      limit: limit,
    );
  }
}
