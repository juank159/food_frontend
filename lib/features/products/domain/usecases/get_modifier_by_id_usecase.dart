import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/modifier.dart';
import '../repositories/product_repository.dart';

/// Get Modifier By ID Use Case
/// Obtiene un modificador específico por su ID
class GetModifierByIdUseCase {
  final ProductRepository repository;

  GetModifierByIdUseCase(this.repository);

  Future<Either<Failure, Modifier>> call(String id) async {
    return await repository.getModifierById(id);
  }
}
