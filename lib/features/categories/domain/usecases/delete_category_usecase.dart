import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/category_repository.dart';

/// Delete Category Use Case
/// Elimina una categoría por su ID
class DeleteCategoryUseCase {
  final CategoryRepository repository;

  DeleteCategoryUseCase(this.repository);

  Future<Either<Failure, void>> call(String id) async {
    return await repository.deleteCategory(id);
  }
}
