import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

import 'package:food_platform_app/core/error/failures.dart';
import 'package:food_platform_app/features/shifts/domain/entities/shift.dart';
import 'package:food_platform_app/features/shifts/domain/repositories/shift_repository.dart';
import 'package:food_platform_app/features/shifts/domain/usecases/shift_usecases.dart';
import 'package:food_platform_app/features/shifts/presentation/bindings/shift_binding.dart';
import 'package:food_platform_app/features/shifts/presentation/controllers/shift_controller.dart';

/// Smoke test del binding: verificamos que `dependencies()` registra el
/// controller sin crashear cuando GetIt está configurado.
///
/// Cubre el bug típico que tumba pantallas enteras en runtime: un
/// binding que olvida una dependencia y crashea al primer paint.
void main() {
  setUp(() {
    if (GetIt.I.isRegistered<ShiftUseCases>()) {
      GetIt.I.unregister<ShiftUseCases>();
    }
    Get.reset();
    GetIt.I.registerLazySingleton<ShiftUseCases>(
      () => ShiftUseCases(_FakeShiftRepo()),
    );
  });

  tearDown(() {
    Get.reset();
    if (GetIt.I.isRegistered<ShiftUseCases>()) {
      GetIt.I.unregister<ShiftUseCases>();
    }
  });

  test('ShiftBinding.dependencies() registra el controller sin crashear', () {
    final binding = ShiftBinding();
    expect(() => binding.dependencies(), returnsNormally);
    expect(Get.isRegistered<ShiftController>(), isTrue);
  });

  test('ShiftController inyectado tiene useCases correctos', () {
    ShiftBinding().dependencies();
    final controller = Get.find<ShiftController>();
    expect(controller.useCases, isA<ShiftUseCases>());
  });
}

class _FakeShiftRepo implements ShiftRepository {
  @override
  Future<Either<Failure, Shift>> clockIn({String? notes}) async =>
      Left(ServerFailure('test'));
  @override
  Future<Either<Failure, Shift>> clockOut({String? notes}) async =>
      Left(ServerFailure('test'));
  @override
  Future<Either<Failure, Shift?>> getMyCurrent() async => const Right(null);
  @override
  Future<Either<Failure, List<Shift>>> getMine({
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async =>
      const Right(<Shift>[]);
  @override
  Future<Either<Failure, List<Shift>>> getActiveStaff() async =>
      const Right(<Shift>[]);
}
