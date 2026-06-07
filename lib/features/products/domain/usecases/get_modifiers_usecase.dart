import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/modifier.dart';
import '../repositories/product_repository.dart';

/// Get Modifiers Use Case
/// Obtiene la lista de modificadores con filtros opcionales
class GetModifiersUseCase {
  final ProductRepository repository;

  GetModifiersUseCase(this.repository);

  Future<Either<Failure, List<Modifier>>> call({
    String? productId,
    String? categoryId,
    bool? isAvailable,
  }) async {
    return await repository.getModifiers(
      productId: productId,
      categoryId: categoryId,
      isAvailable: isAvailable,
    );
  }
}
