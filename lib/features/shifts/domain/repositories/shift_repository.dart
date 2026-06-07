import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/shift.dart';

abstract class ShiftRepository {
  Future<Either<Failure, Shift>> clockIn({String? notes});
  Future<Either<Failure, Shift>> clockOut({String? notes});
  Future<Either<Failure, Shift?>> getMyCurrent();
  Future<Either<Failure, List<Shift>>> getMine({
    DateTime? from,
    DateTime? to,
    int? limit,
  });
  Future<Either<Failure, List<Shift>>> getActiveStaff();
}
