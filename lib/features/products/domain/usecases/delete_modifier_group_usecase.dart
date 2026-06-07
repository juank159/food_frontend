import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/product_repository.dart';

/// Delete Modifier Group Use Case
/// Elimina un grupo de modificadores
class DeleteModifierGroupUseCase {
  final ProductRepository repository;

  DeleteModifierGroupUseCase(this.repository);

  Future<Either<Failure, void>> call(String id) async {
    return await repository.deleteModifierGroup(id);
  }
}
