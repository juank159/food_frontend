import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/modifier_enums.dart';
import '../../../../core/error/failures.dart';
import '../entities/modifier_group.dart';
import '../repositories/product_repository.dart';

/// Update Modifier Group Use Case
/// Actualiza un grupo de modificadores existente
class UpdateModifierGroupUseCase {
  final ProductRepository repository;

  UpdateModifierGroupUseCase(this.repository);

  Future<Either<Failure, ModifierGroup>> call({
    required String id,
    String? name,
    String? description,
    SelectionType? selectionType,
    int? minSelections,
    int? maxSelections,
    bool? isRequired,
    int? sortOrder,
  }) async {
    return await repository.updateModifierGroup(
      id: id,
      name: name,
      description: description,
      selectionType: selectionType,
      minSelections: minSelections,
      maxSelections: maxSelections,
      isRequired: isRequired,
      sortOrder: sortOrder,
    );
  }
}
