import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/modifier_enums.dart';
import '../../../../core/error/failures.dart';
import '../entities/modifier_group.dart';
import '../repositories/product_repository.dart';

/// Create Modifier Group Use Case
/// Crea un nuevo grupo de modificadores para un producto
class CreateModifierGroupUseCase {
  final ProductRepository repository;

  CreateModifierGroupUseCase(this.repository);

  Future<Either<Failure, ModifierGroup>> call({
    required String name,
    required String productId,
    String? description,
    required SelectionType selectionType,
    int? minSelections,
    int? maxSelections,
    bool? isRequired,
    int? sortOrder,
    List<String>? modifierIds,
  }) async {
    return await repository.createModifierGroup(
      name: name,
      productId: productId,
      description: description,
      selectionType: selectionType,
      minSelections: minSelections,
      maxSelections: maxSelections,
      isRequired: isRequired,
      sortOrder: sortOrder,
      modifierIds: modifierIds,
    );
  }
}
