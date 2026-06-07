import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/cash_session.dart';
import '../repositories/cash_session_repository.dart';

/// Bundle de use cases del feature — agrupados porque cada uno es un
/// thin wrapper sobre el repository.
class CashSessionUseCases {
  final CashSessionRepository repository;

  CashSessionUseCases(this.repository);

  Future<Either<Failure, CashSession>> open({
    required double openingAmount,
    String? notes,
  }) =>
      repository.open(openingAmount: openingAmount, notes: notes);

  Future<Either<Failure, CashSession?>> getCurrent() =>
      repository.getCurrent();

  Future<Either<Failure, CashSession>> findOne(String id) =>
      repository.findOne(id);

  Future<Either<Failure, List<CashSession>>> findAll({
    CashSessionStatus? status,
    String? openedBy,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) =>
      repository.findAll(
        status: status,
        openedBy: openedBy,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

  Future<Either<Failure, Map<String, dynamic>>> getReport(String id) =>
      repository.getReport(id);

  Future<Either<Failure, CashSession>> close({
    required String id,
    required double closingAmountCounted,
    String? closingNotes,
    bool force = false,
  }) =>
      repository.close(
        id: id,
        closingAmountCounted: closingAmountCounted,
        closingNotes: closingNotes,
        force: force,
      );

  Future<Either<Failure, void>> voidSession(String id) =>
      repository.voidSession(id);
}
