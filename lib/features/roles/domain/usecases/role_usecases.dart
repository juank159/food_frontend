import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/role.dart';
import '../repositories/role_repository.dart';

class RoleUseCases {
  final RoleRepository repository;
  RoleUseCases(this.repository);

  Future<Either<Failure, List<Role>>> findAll() => repository.findAll();
  Future<Either<Failure, Role>> findOne(String id) => repository.findOne(id);

  Future<Either<Failure, Role>> create({
    required String name,
    required String code,
    required Map<String, List<String>> permissions,
    String? description,
    bool? isActive,
    int? sortOrder,
  }) =>
      repository.create(
        name: name,
        code: code,
        permissions: permissions,
        description: description,
        isActive: isActive,
        sortOrder: sortOrder,
      );

  Future<Either<Failure, Role>> update(
    String id, {
    String? name,
    String? description,
    Map<String, List<String>>? permissions,
    bool? isActive,
    int? sortOrder,
  }) =>
      repository.update(
        id,
        name: name,
        description: description,
        permissions: permissions,
        isActive: isActive,
        sortOrder: sortOrder,
      );

  Future<Either<Failure, void>> remove(String id) => repository.remove(id);
}
