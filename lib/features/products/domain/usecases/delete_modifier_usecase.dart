import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/product_repository.dart';

/// Delete Modifier Use Case
/// Elimina un modificador
class DeleteModifierUseCase {
  final ProductRepository repository;

  DeleteModifierUseCase(this.repository);

  Future<Either<Failure, void>> call(String id) async {
    return await repository.deleteModifier(id);
  }
}
