import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/category.dart';
import '../repositories/category_repository.dart';

/// Get Active Categories Use Case
/// Obtiene solo las categorías activas
class GetActiveCategoriesUseCase {
  final CategoryRepository repository;

  GetActiveCategoriesUseCase(this.repository);

  Future<Either<Failure, List<Category>>> call() async {
    return await repository.getActiveCategories();
  }
}
