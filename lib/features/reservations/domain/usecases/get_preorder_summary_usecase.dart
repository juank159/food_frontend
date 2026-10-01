import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/reservation_preorder.dart';
import '../repositories/reservation_repository.dart';

/// Resumen del pre-pedido agrupado por invitado, para que el restaurante
/// lo revise antes de que llegue el grupo.
class GetPreorderSummaryUseCase {
  final ReservationRepository repository;

  GetPreorderSummaryUseCase(this.repository);

  Future<Either<Failure, ReservationPreorderSummary>> call(String id) {
    return repository.getPreorderSummary(id);
  }
}
