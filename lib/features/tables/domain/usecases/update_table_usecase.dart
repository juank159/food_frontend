// lib/features/tables/domain/usecases/update_table_usecase.dart

import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/table_enums.dart';
import '../../../../core/error/failures.dart';
import '../entities/table.dart';
import '../repositories/table_repository.dart';

/// Use case para actualizar una mesa existente
class UpdateTableUseCase {
  final TableRepository repository;

  UpdateTableUseCase(this.repository);

  Future<Either<Failure, RestaurantTable>> call({
    required String id,
    required Map<String, dynamic> tableData,
  }) async {
    return await repository.updateTable(
      id: id,
      tableNumber: tableData['table_number'] as String?,
      name: tableData['name'] as String?,
      capacity: tableData['capacity'] as int?,
      minCapacity: tableData['min_capacity'] as int?,
      status: tableData['status'] != null
          ? TableStatus.fromString(tableData['status'] as String)
          : null,
      tableType: tableData['table_type'] != null
          ? TableType.fromString(tableData['table_type'] as String)
          : null,
      shape: tableData['shape'] != null
          ? TableShape.fromString(tableData['shape'] as String)
          : null,
      zone: tableData['zone'] as String?,
      section: tableData['section'] as String?,
      isActive: tableData['is_active'] as bool?,
      positionX: tableData['position_x'] != null
          ? (tableData['position_x'] as double).toInt()
          : null,
      positionY: tableData['position_y'] != null
          ? (tableData['position_y'] as double).toInt()
          : null,
      width: tableData['width'] as double?,
      height: tableData['height'] as double?,
      metadata: tableData['metadata'] as Map<String, dynamic>?,
    );
  }
}
