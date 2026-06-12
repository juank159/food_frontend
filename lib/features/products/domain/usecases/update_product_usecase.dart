import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';

/// Update Product Use Case
/// Actualiza un producto existente
class UpdateProductUseCase {
  final ProductRepository repository;

  UpdateProductUseCase(this.repository);

  Future<Either<Failure, Product>> call({
    required String id,
    String? name,
    double? basePrice,
    String? sku,
    String? categoryId,
    String? description,
    double? cost,
    bool? requiresPreparation,
    int? preparationTime,
    String? imageUrl,
    List<String>? images,
    String? barcode,
    bool? isAvailable,
    bool? isFeatured,
    List<String>? tags,
    List<String>? allergens,
    Map<String, dynamic>? nutritionalInfo,
    bool? trackInventory,
    int? currentStock,
    int? minStockAlert,
    int? sortOrder,
    Map<String, dynamic>? metadata,
  }) async {
    return await repository.updateProduct(
      id: id,
      name: name,
      basePrice: basePrice,
      sku: sku,
      categoryId: categoryId,
      description: description,
      cost: cost,
      requiresPreparation: requiresPreparation,
      preparationTime: preparationTime,
      imageUrl: imageUrl,
      images: images,
      barcode: barcode,
      isAvailable: isAvailable,
      isFeatured: isFeatured,
      tags: tags,
      allergens: allergens,
      nutritionalInfo: nutritionalInfo,
      trackInventory: trackInventory,
      currentStock: currentStock,
      minStockAlert: minStockAlert,
      sortOrder: sortOrder,
      metadata: metadata,
    );
  }
}
