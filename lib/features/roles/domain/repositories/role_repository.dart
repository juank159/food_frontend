import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/role.dart';

abstract class RoleRepository {
  Future<Either<Failure, List<Role>>> findAll();
  Future<Either<Failure, Role>> findOne(String id);
  Future<Either<Failure, Role>> create({
    required String name,
    required String code,
    required Map<String, List<String>> permissions,
    String? description,
    bool? isActive,
    int? sortOrder,
  });
  Future<Either<Failure, Role>> update(
    String id, {
    String? name,
    String? description,
    Map<String, List<String>>? permissions,
    bool? isActive,
    int? sortOrder,
  });
  Future<Either<Failure, void>> remove(String id);
}
