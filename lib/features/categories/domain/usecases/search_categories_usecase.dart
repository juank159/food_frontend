// lib/features/categories/domain/usecases/search_categories_usecase.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/category.dart';
import '../repositories/category_repository.dart';

/// Search Categories Use Case
/// Busca categorías por nombre o descripción
class SearchCategoriesUseCase {
  final CategoryRepository repository;

  SearchCategoriesUseCase(this.repository);

  Future<Either<Failure, List<Category>>> call(String query) async {
    return await repository.searchCategories(query);
  }
}
