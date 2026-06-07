import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/modifier_group.dart';
import '../repositories/product_repository.dart';

/// Add Modifiers To Group Use Case
/// Asocia uno o más modificadores existentes a un grupo de modificadores.
class AddModifiersToGroupUseCase {
  final ProductRepository repository;

  AddModifiersToGroupUseCase(this.repository);

  Future<Either<Failure, ModifierGroup>> call({
    required String groupId,
    required List<String> modifierIds,
  }) async {
    return await repository.addModifiersToGroup(
      groupId: groupId,
      modifierIds: modifierIds,
    );
  }
}
