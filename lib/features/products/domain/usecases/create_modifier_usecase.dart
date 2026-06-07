import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/modifier_enums.dart';
import '../../../../core/error/failures.dart';
import '../entities/modifier.dart';
import '../repositories/product_repository.dart';

/// Create Modifier Use Case
/// Crea un nuevo modificador para productos
class CreateModifierUseCase {
  final ProductRepository repository;

  CreateModifierUseCase(this.repository);

  Future<Either<Failure, Modifier>> call({
    required String name,
    String? description,
    required ModifierType type,
    required double price,
    int? maxQuantity,
    bool? isAvailable,
    int? sortOrder,
    List<String>? productIds,
    List<String>? categoryIds,
  }) async {
    return await repository.createModifier(
      name: name,
      description: description,
      type: type,
      price: price,
      maxQuantity: maxQuantity,
      isAvailable: isAvailable,
      sortOrder: sortOrder,
      productIds: productIds,
      categoryIds: categoryIds,
    );
  }
}
