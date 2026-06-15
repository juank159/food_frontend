import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/product_variant.dart';
import '../repositories/product_repository.dart';

/// Create Variant Use Case
/// Crea una nueva variante para un producto
class CreateVariantUseCase {
  final ProductRepository repository;

  CreateVariantUseCase(this.repository);

  Future<Either<Failure, ProductVariant>> call({
    required String productId,
    required String name,
    required double priceModifier,
    String? description,
    bool? isDefault,
    int? sortOrder,
    bool? isAvailable,
    String? sku,
    int? scoopCount,
  }) async {
    return await repository.createVariant(
      productId: productId,
      name: name,
      priceModifier: priceModifier,
      description: description,
      isDefault: isDefault,
      sortOrder: sortOrder,
      isAvailable: isAvailable,
      sku: sku,
      scoopCount: scoopCount,
    );
  }
}
