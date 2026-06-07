import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/table.dart';
import '../repositories/table_repository.dart';

/// Update Table Position Use Case
/// Actualiza la posición de una mesa en el mapa visual
class UpdateTablePositionUseCase {
  final TableRepository repository;

  UpdateTablePositionUseCase(this.repository);

  Future<Either<Failure, RestaurantTable>> call({
    required String id,
    required double positionX,
    required double positionY,
    double? width,
    double? height,
    String? shape,
  }) async {
    return await repository.updateTablePosition(
      id: id,
      positionX: positionX,
      positionY: positionY,
      width: width,
      height: height,
      shape: shape,
    );
  }
}
