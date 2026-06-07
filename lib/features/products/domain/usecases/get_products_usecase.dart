import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';

/// Get Products Use Case
/// Obtiene la lista de productos con filtros opcionales
class GetProductsUseCase {
  final ProductRepository repository;

  GetProductsUseCase(this.repository);

  Future<Either<Failure, List<Product>>> call({
    String? categoryId,
    bool? isAvailable,
    String? search,
    List<String>? tags,
    int? page,
    int? limit,
  }) async {
    return await repository.getProducts(
      categoryId: categoryId,
      isAvailable: isAvailable,
      search: search,
      tags: tags,
      page: page,
      limit: limit,
    );
  }
}
