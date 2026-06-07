import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/product_variant.dart';
import '../repositories/product_repository.dart';

/// Update Variant Use Case
/// Actualiza una variante existente
class UpdateVariantUseCase {
  final ProductRepository repository;

  UpdateVariantUseCase(this.repository);

  Future<Either<Failure, ProductVariant>> call({
    required String variantId,
    String? name,
    double? priceModifier,
    String? description,
    bool? isDefault,
    int? sortOrder,
    bool? isAvailable,
    String? sku,
  }) async {
    return await repository.updateVariant(
      variantId: variantId,
      name: name,
      priceModifier: priceModifier,
      description: description,
      isDefault: isDefault,
      sortOrder: sortOrder,
      isAvailable: isAvailable,
      sku: sku,
    );
  }
}
