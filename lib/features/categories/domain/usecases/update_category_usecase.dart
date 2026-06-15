import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/category.dart';
import '../repositories/category_repository.dart';

/// Update Category Use Case
/// Actualiza una categoría existente
class UpdateCategoryUseCase {
  final CategoryRepository repository;

  UpdateCategoryUseCase(this.repository);

  Future<Either<Failure, Category>> call({
    required String id,
    String? name,
    String? description,
    String? imageUrl,
    String? color,
    String? icon,
    bool? isActive,
    int? displayOrder,
    String? parentId,
    bool? printsKitchen,
  }) async {
    return await repository.updateCategory(
      id: id,
      name: name,
      description: description,
      imageUrl: imageUrl,
      color: color,
      icon: icon,
      isActive: isActive,
      displayOrder: displayOrder,
      parentId: parentId,
      printsKitchen: printsKitchen,
    );
  }
}
