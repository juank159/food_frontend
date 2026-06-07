import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/product_repository.dart';

/// Delete Variant Use Case
/// Elimina una variante (soft delete)
class DeleteVariantUseCase {
  final ProductRepository repository;

  DeleteVariantUseCase(this.repository);

  Future<Either<Failure, void>> call(String variantId) async {
    return await repository.deleteVariant(variantId);
  }
}
