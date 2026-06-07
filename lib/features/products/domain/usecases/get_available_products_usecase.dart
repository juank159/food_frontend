import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';

/// Get Available Products Use Case
/// Obtiene solo los productos disponibles para venta
class GetAvailableProductsUseCase {
  final ProductRepository repository;

  GetAvailableProductsUseCase(this.repository);

  Future<Either<Failure, List<Product>>> call() async {
    return await repository.getAvailableProducts();
  }
}
