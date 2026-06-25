import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/category.dart';
import '../repositories/category_repository.dart';

class CreateCategoryUseCase {
  final CategoryRepository repository;

  CreateCategoryUseCase(this.repository);

  Future<Either<Failure, Category>> call({
    required String name,
    required String description,
    String? imageUrl,
    String? color,
    String? icon,
    bool isActive = true,
    int displayOrder = 0,
    String? parentId,
    bool printsKitchen = true,
    List<String>? quickNotes,
    String? flavorLabel,
  }) async {
    return await repository.createCategory(
      name: name,
      description: description,
      imageUrl: imageUrl,
      color: color,
      icon: icon,
      isActive: isActive,
      displayOrder: displayOrder,
      parentId: parentId,
      printsKitchen: printsKitchen,
      quickNotes: quickNotes,
      flavorLabel: flavorLabel,
    );
  }
}
