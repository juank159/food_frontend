import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/shift.dart';
import '../repositories/shift_repository.dart';

/// Facade simple para los flujos de turnos. Mantenemos los use cases
/// agrupados (no uno por método) porque la feature es chica.
class ShiftUseCases {
  final ShiftRepository repository;

  ShiftUseCases(this.repository);

  Future<Either<Failure, Shift>> clockIn({String? notes}) =>
      repository.clockIn(notes: notes);

  Future<Either<Failure, Shift>> clockOut({String? notes}) =>
      repository.clockOut(notes: notes);

  Future<Either<Failure, Shift?>> getMyCurrent() => repository.getMyCurrent();

  Future<Either<Failure, List<Shift>>> getMine({
    DateTime? from,
    DateTime? to,
    int? limit,
  }) =>
      repository.getMine(from: from, to: to, limit: limit);

  Future<Either<Failure, List<Shift>>> getActiveStaff() =>
      repository.getActiveStaff();
}
