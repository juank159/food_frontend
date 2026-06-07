import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/modifier_enums.dart';
import '../../../../core/error/failures.dart';
import '../entities/modifier.dart';
import '../repositories/product_repository.dart';

/// Update Modifier Use Case
/// Actualiza un modificador existente
class UpdateModifierUseCase {
  final ProductRepository repository;

  UpdateModifierUseCase(this.repository);

  Future<Either<Failure, Modifier>> call({
    required String id,
    String? name,
    String? description,
    ModifierType? type,
    double? price,
    int? maxQuantity,
    bool? isAvailable,
    int? sortOrder,
    List<String>? productIds,
    List<String>? categoryIds,
  }) async {
    return await repository.updateModifier(
      id: id,
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
