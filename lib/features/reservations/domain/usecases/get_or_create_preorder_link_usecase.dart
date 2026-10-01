import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/reservation_preorder.dart';
import '../repositories/reservation_repository.dart';

/// Genera (o devuelve) el link público de pre-pedido colaborativo de
/// una reserva, para compartir con el grupo.
class GetOrCreatePreorderLinkUseCase {
  final ReservationRepository repository;

  GetOrCreatePreorderLinkUseCase(this.repository);

  Future<Either<Failure, ReservationPreorderLink>> call(String id) {
    return repository.getOrCreatePreorderLink(id);
  }
}
