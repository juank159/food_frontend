import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/cash_session.dart';

abstract class CashSessionRepository {
  Future<Either<Failure, CashSession>> open({
    required double openingAmount,
    String? notes,
  });

  /// Sesión abierta del usuario actual, o null si no tiene caja abierta.
  Future<Either<Failure, CashSession?>> getCurrent();

  Future<Either<Failure, CashSession>> findOne(String id);

  /// Listado con filtros — para histórico (admin/manager).
  Future<Either<Failure, List<CashSession>>> findAll({
    CashSessionStatus? status,
    String? openedBy,
    DateTime? dateFrom,
    DateTime? dateTo,
  });

  /// Reporte detallado (X de caja parcial o Z de cierre).
  Future<Either<Failure, Map<String, dynamic>>> getReport(String id);

  Future<Either<Failure, CashSession>> close({
    required String id,
    required double closingAmountCounted,
    String? closingNotes,
    bool force = false,
  });

  Future<Either<Failure, void>> voidSession(String id);
}
