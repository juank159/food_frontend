import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/category.dart';
import '../repositories/category_repository.dart';

/// Toggle Category Status Use Case
/// Activa o desactiva una categoría
class ToggleCategoryStatusUseCase {
  final CategoryRepository repository;

  ToggleCategoryStatusUseCase(this.repository);

  Future<Either<Failure, Category>> call({
    required String id,
    required bool isActive,
  }) async {
    return await repository.updateCategory(
      id: id,
      isActive: isActive,
    );
  }
}
