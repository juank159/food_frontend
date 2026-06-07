import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

import 'package:food_platform_app/core/error/failures.dart';
import 'package:food_platform_app/features/roles/domain/entities/role.dart';
import 'package:food_platform_app/features/roles/domain/repositories/role_repository.dart';
import 'package:food_platform_app/features/roles/domain/usecases/role_usecases.dart';
import 'package:food_platform_app/features/roles/presentation/bindings/role_binding.dart';
import 'package:food_platform_app/features/roles/presentation/controllers/role_controller.dart';

void main() {
  setUp(() {
    if (GetIt.I.isRegistered<RoleUseCases>()) {
      GetIt.I.unregister<RoleUseCases>();
    }
    Get.reset();
    GetIt.I.registerLazySingleton<RoleUseCases>(
      () => RoleUseCases(_FakeRoleRepo()),
    );
  });

  tearDown(() {
    Get.reset();
    if (GetIt.I.isRegistered<RoleUseCases>()) {
      GetIt.I.unregister<RoleUseCases>();
    }
  });

  test('RoleBinding.dependencies() registra el controller sin crashear', () {
    final binding = RoleBinding();
    expect(() => binding.dependencies(), returnsNormally);
    expect(Get.isRegistered<RoleController>(), isTrue);
  });

  test('RoleController inyectado tiene useCases correctos', () {
    RoleBinding().dependencies();
    final controller = Get.find<RoleController>();
    expect(controller.useCases, isA<RoleUseCases>());
  });
}

class _FakeRoleRepo implements RoleRepository {
  @override
  Future<Either<Failure, List<Role>>> findAll() async => const Right(<Role>[]);
  @override
  Future<Either<Failure, Role>> findOne(String id) async =>
      Left(ServerFailure('test'));
  @override
  Future<Either<Failure, Role>> create({
    required String name,
    required String code,
    required Map<String, List<String>> permissions,
    String? description,
    bool? isActive,
    int? sortOrder,
  }) async =>
      Left(ServerFailure('test'));
  @override
  Future<Either<Failure, Role>> update(
    String id, {
    String? name,
    String? description,
    Map<String, List<String>>? permissions,
    bool? isActive,
    int? sortOrder,
  }) async =>
      Left(ServerFailure('test'));
  @override
  Future<Either<Failure, void>> remove(String id) async =>
      const Right(null);
}
