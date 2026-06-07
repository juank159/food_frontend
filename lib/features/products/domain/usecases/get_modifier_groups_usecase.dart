import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/modifier_group.dart';
import '../repositories/product_repository.dart';

/// Get Modifier Groups Use Case
/// Obtiene la lista de grupos de modificadores
class GetModifierGroupsUseCase {
  final ProductRepository repository;

  GetModifierGroupsUseCase(this.repository);

  Future<Either<Failure, List<ModifierGroup>>> call({
    String? productId,
    bool? isActive,
  }) async {
    return await repository.getModifierGroups(
      productId: productId,
      isActive: isActive,
    );
  }
}
