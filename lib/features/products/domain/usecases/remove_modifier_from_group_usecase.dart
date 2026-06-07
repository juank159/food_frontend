import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/product_repository.dart';

/// Remove Modifier From Group Use Case
/// Desasocia un modificador de un grupo de modificadores.
class RemoveModifierFromGroupUseCase {
  final ProductRepository repository;

  RemoveModifierFromGroupUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String groupId,
    required String modifierId,
  }) async {
    return await repository.removeModifierFromGroup(
      groupId: groupId,
      modifierId: modifierId,
    );
  }
}
