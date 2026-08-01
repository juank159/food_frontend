import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/tab_session.dart';
import '../repositories/tab_session_repository.dart';

class TabSessionUseCases {
  final TabSessionRepository repository;

  TabSessionUseCases(this.repository);

  Future<Either<Failure, TabSession>> open({
    String? tableElementId,
    String? tableId,
    String? customerId,
    int? partySize,
    String? notes,
  }) {
    return repository.open(
      tableElementId: tableElementId,
      tableId: tableId,
      customerId: customerId,
      partySize: partySize,
      notes: notes,
    );
  }

  Future<Either<Failure, List<TabSession>>> findOpen() => repository.findOpen();

  Future<Either<Failure, TabSession>> findOne(String id) =>
      repository.findOne(id);

  Future<Either<Failure, TabSession>> update(
    String id, {
    String? customerName,
    String? notes,
    int? partySize,
  }) {
    return repository.update(id, customerName: customerName, notes: notes, partySize: partySize);
  }

  Future<Either<Failure, TabSession>> close({
    required String id,
    bool force = false,
    String? notes,
  }) {
    return repository.close(id: id, force: force, notes: notes);
  }

  Future<Either<Failure, void>> voidSession(String id) =>
      repository.voidSession(id);
}
